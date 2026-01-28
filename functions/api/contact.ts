interface KvNamespace 
{
  put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void>;
  get(key: string): Promise<string | null>;
}

interface ContactEnv 
{
  TURNSTILE_SECRET_KEY?: string;
  RESEND_API_KEY?: string;
  CONTACT_LOG?: KvNamespace;
}

interface ContactContext 
{
  request: Request;
  env: ContactEnv;
}

interface ContactLogEntry 
{
  ts: number;
  email: string;
  subject: string;
  message: string;
}

interface TurnstileVerifyResponse 
{
  success: boolean;
  ["error-codes"]?: string[];
}

interface ResendErrorResponse 
{
  message?: string;
}

interface ResendEmailPayload 
{
  from: string;
  to: string[];
  reply_to: string;
  subject: string;
  text: string;
  html: string;
}

export function onRequestPost(context: ContactContext): Promise<Response>
{
    return ContactRequestHandler.HandleAsync(context);
}

class ContactRequestHandler
{
    private static readonly EmailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    private static readonly MaxEmailLength = 320;
    private static readonly MaxSubjectLength = 120;
    private static readonly MaxBodyBytes = 20000; // conservative form size guard
    private static readonly MaxBodyChars = 8000;  // combined email+subject+message guard
    private static readonly MaxMessageLength = 4000; // truncate before logging/sending
    private static readonly RateLimitMaxRequests = 5;
    private static readonly RateLimitWindowMs = 60 * 60 * 1000; // 1 hour
    private static readonly ResendSubjectSliceLength = 90;
    private static readonly EmailSubjectPrefix = "Website Message: ";

    public static async HandleAsync({ request, env }: ContactContext): Promise<Response>
    {
        // Cheap size check before reading the body
        const contentLength = request.headers.get("content-length");
        if (contentLength && parseInt(contentLength, 10) > this.MaxBodyBytes)
        {
            return this.PayloadTooLarge("Request body too large");
        }

        const form = await request.formData();

        const email = this.getFormValue(form, "email", { trim: true });
        const subject = this.getFormValue(form, "subject", { trim: true });
        const message = this.getFormValue(form, "message");
        const nickname = this.getFormValue(form, "nickname");
        const turnstileToken = this.getFormValue(form, "cf-turnstile-response");
        const trimmedMessage = message.trim();

        const totalChars = email.length + subject.length + trimmedMessage.length;
        if (totalChars > this.MaxBodyChars)
        {
            return this.PayloadTooLarge("Combined fields too large");
        }

        const safeMessage = trimmedMessage.slice(0, this.MaxMessageLength);

        if (nickname)
        {
            return this.Redirect("/contact/sent", 302);
        }

        if (!email || !subject || !trimmedMessage)
        {
            return this.BadRequest("Missing fields");
        }

        if (!this.IsValidEmail(email))
        {
            return this.BadRequest("Invalid email address");
        }

        if (!this.IsValidSubject(subject))
        {
            return this.BadRequest("Invalid subject");
        }

        if (!turnstileToken)
        {
            return this.BadRequest("Turnstile token missing");
        }

        if (!env.TURNSTILE_SECRET_KEY)
        {
            return this.ServerError("Turnstile secret key not configured");
        }

        if (env.CONTACT_LOG && "get" in env.CONTACT_LOG)
        {
            const rateCheck = await this.CheckRateLimit(request, env.CONTACT_LOG);
            if (!rateCheck.ok)
            {
                return this.TooManyRequests(rateCheck.message);
            }
        }

        const turnstileResp = await fetch(
            "https://challenges.cloudflare.com/turnstile/v0/siteverify",
            {
                method: "POST",
                body: new URLSearchParams({
                    secret: env.TURNSTILE_SECRET_KEY,
                    response: turnstileToken
                })
            }
        );

        const turnstileResult = (await turnstileResp.json()) as TurnstileVerifyResponse;

        if (!turnstileResult.success)
        {
            const errorCodes = turnstileResult["error-codes"]?.join(", ") || "Unknown error";
            console.error("Turnstile validation failed:", turnstileResult);
            return this.BadRequest(`Turnstile validation failed: ${errorCodes}`);
        }

        const timestamp = Date.now();

        if (env.CONTACT_LOG)
        {
            const entry: ContactLogEntry = {
                ts: timestamp,
                email,
                subject,
                message: safeMessage
            };

            await env.CONTACT_LOG.put(`msg-${timestamp}`, JSON.stringify(entry));
        }

        if (!env.RESEND_API_KEY)
        {
            return this.ServerError("Resend API key not configured");
        }

        const normalizedSubject = this.NormalizeSubject(subject);
        const truncatedSubject =
            normalizedSubject.length > this.ResendSubjectSliceLength
                ? normalizedSubject.slice(0, this.ResendSubjectSliceLength).trimEnd()
                : normalizedSubject;
        const composedSubject = `${this.EmailSubjectPrefix}${truncatedSubject}`;
        const htmlMessage = this.EscapeHtml(safeMessage).replace(/\r?\n/g, "<br>");

        const payload: ResendEmailPayload = {
            from: "Steven Goulet Website <noreply@stevengoulet.com>",
            to: ["steveng57@outlook.com"],
            reply_to: email,
            subject: composedSubject,
            text: `New message from stevengoulet.com

From: ${email}

Subject: ${normalizedSubject}

Message:
${safeMessage}`,
            html: `
                <h2>New message from stevengoulet.com</h2>
                <p><strong>From:</strong> ${this.EscapeHtml(email)}</p>
                <p><strong>Subject:</strong> ${this.EscapeHtml(normalizedSubject)}</p>
                <p><strong>Message:</strong></p>
                <p>${htmlMessage}</p>
            `.trim()
        };

        const resp = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${env.RESEND_API_KEY}`
            },
            body: JSON.stringify(payload)
        });

        if (!resp.ok)
        {
            let errorDetail = "";

            try
            {
                const errorJson = (await resp.json()) as ResendErrorResponse;
                errorDetail = errorJson?.message ?? JSON.stringify(errorJson);
            }
            catch
            {
                errorDetail = await resp.text();
            }

            console.error("Resend error:", resp.status, errorDetail);
            return this.ServerError(`Error sending email: ${resp.status} ${errorDetail}`);
        }

        return this.Redirect("/contact/sent");
    }

    private static getFormValue(form: FormData, key: string, options?: { trim?: boolean }): string
    {
        const value = form.get(key);

        if (typeof value !== "string")
        {
            return "";
        }

        if (options?.trim)
        {
            return value.trim();
        }

        return value;
    }

    private static EscapeHtml(value: string): string
    {
        return value
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;");
    }

    private static IsValidEmail(address: string): boolean
    {
        return (
            Boolean(address) &&
            address.length <= this.MaxEmailLength &&
            this.EmailRegex.test(address)
        );
    }

    private static IsValidSubject(subject: string): boolean
    {
        if (!subject)
        {
            return false;
        }

        const trimmed = subject.trim();

        if (!trimmed || trimmed.length > this.MaxSubjectLength)
        {
            return false;
        }

        return !/[<>]/.test(trimmed);
    }

    private static NormalizeSubject(value: string): string
    {
        return value.replace(/\s+/g, " ").trim();
    }

    private static BadRequest(message: string): Response
    {
        return new Response(message, { status: 400 });
    }

    private static ServerError(message: string): Response
    {
        return new Response(message, { status: 500 });
    }

    private static Redirect(location: string, status: number = 303): Response
    {
        return new Response(null, {
            status,
            headers: { Location: location }
        });
    }

    private static PayloadTooLarge(message: string): Response
    {
        return new Response(message, { status: 413 });
    }

    private static TooManyRequests(message: string): Response
    {
        return new Response(message, { status: 429 });
    }

    private static GetClientIp(request: Request): string
    {
        const cfIp = request.headers.get("cf-connecting-ip");
        if (cfIp) return cfIp;

        const xff = request.headers.get("x-forwarded-for");
        if (xff) return xff.split(",")[0].trim();

        return "unknown";
    }

    private static async CheckRateLimit(request: Request, kv: KvNamespace): Promise<{ ok: boolean; message?: string }>
    {
        const ip = this.GetClientIp(request);
        if (!ip || ip === "unknown")
        {
            return { ok: true };
        }

        const rateKey = `rate-${ip}`;
        let count = 0;
        let windowStart = Date.now();

        try
        {
            const existing = await kv.get(rateKey);
            if (existing)
            {
                const parsed = JSON.parse(existing) as { count: number; windowStart: number };
                count = parsed.count || 0;
                windowStart = parsed.windowStart || windowStart;
            }
        }
        catch
        {
            /* ignore parse errors and treat as empty */
        }

        const now = Date.now();
        if (now - windowStart > this.RateLimitWindowMs)
        {
            count = 0;
            windowStart = now;
        }

        count += 1;

        if (count > this.RateLimitMaxRequests)
        {
            return { ok: false, message: "Too many submissions. Please try again later." };
        }

        await kv.put(rateKey, JSON.stringify({ count, windowStart }), { expirationTtl: Math.ceil(this.RateLimitWindowMs / 1000) });

        return { ok: true };
    }
}

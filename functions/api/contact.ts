interface KvNamespace 
{
  put(key: string, value: string): Promise<void>;
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
    private static readonly ResendSubjectSliceLength = 90;
    private static readonly EmailSubjectPrefix = "Website Message: ";

    public static async HandleAsync({ request, env }: ContactContext): Promise<Response>
    {
        const form = await request.formData();

        const email = this.getFormValue(form, "email", { trim: true });
        const subject = this.getFormValue(form, "subject", { trim: true });
        const message = this.getFormValue(form, "message");
        const nickname = this.getFormValue(form, "nickname");
        const turnstileToken = this.getFormValue(form, "cf-turnstile-response");
        const trimmedMessage = message.trim();

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
                message
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
        const htmlMessage = this.EscapeHtml(message).replace(/\r?\n/g, "<br>");

        const payload: ResendEmailPayload = {
            from: "Steven Goulet Website <noreply@stevengoulet.com>",
            to: ["steveng57@outlook.com"],
            reply_to: email,
            subject: composedSubject,
            text: `New message from stevengoulet.com

From: ${email}

Subject: ${normalizedSubject}

Message:
${message}`,
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
}

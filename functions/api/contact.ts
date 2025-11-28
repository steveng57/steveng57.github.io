interface KvNamespace {
  put(key: string, value: string): Promise<void>;
}

interface ContactEnv {
  TURNSTILE_SECRET_KEY?: string;
  RESEND_API_KEY?: string;
  CONTACT_LOG?: KvNamespace;
}

interface ContactContext {
  request: Request;
  env: ContactEnv;
}

interface ContactLogEntry {
  ts: number;
  email: string;
  subject: string;
  message: string;
}

interface TurnstileVerifyResponse {
  success: boolean;
  ["error-codes"]?: string[];
}

interface ResendErrorResponse {
  message?: string;
}

interface ResendEmailPayload {
  from: string;
  to: string[];
  reply_to: string;
  subject: string;
  text: string;
  html: string;
}

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_EMAIL_LENGTH = 320;
const MAX_SUBJECT_LENGTH = 120;
const RESEND_SUBJECT_SLICE_LENGTH = 90;
const EMAIL_SUBJECT_PREFIX = "Website Message: ";

export const onRequestPost = async ({ request, env }: ContactContext): Promise<Response> => {
  const form = await request.formData();

  const emailValue = form.get("email");
  const subjectValue = form.get("subject");
  const messageValue = form.get("message");
  const nicknameValue = form.get("nickname");
  const turnstileValue = form.get("cf-turnstile-response");

  const email = typeof emailValue === "string" ? emailValue.trim() : "";
  const subject = typeof subjectValue === "string" ? subjectValue.trim() : "";
  const message = typeof messageValue === "string" ? messageValue : "";
  const nickname = typeof nicknameValue === "string" ? nicknameValue : "";
  const turnstileToken = typeof turnstileValue === "string" ? turnstileValue : "";
  const trimmedMessage = message.trim();

  if (nickname) {
    return new Response(null, {
      status: 302,
      headers: { Location: "/contact/sent" }
    });
  }

  if (!email || !subject || !trimmedMessage) {
    return new Response("Missing fields", { status: 400 });
  }

  if (!isValidEmail(email)) {
    return new Response("Invalid email address", { status: 400 });
  }

  if (!isValidSubject(subject)) {
    return new Response("Invalid subject", { status: 400 });
  }

  if (!turnstileToken) {
    return new Response("Turnstile token missing", { status: 400 });
  }

  if (!env.TURNSTILE_SECRET_KEY) {
    return new Response("Turnstile secret key not configured", { status: 500 });
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

  if (!turnstileResult.success) {
    const errorCodes = turnstileResult["error-codes"]?.join(", ") || "Unknown error";
    console.error("Turnstile validation failed:", turnstileResult);
    return new Response(`Turnstile validation failed: ${errorCodes}`, {
      status: 400
    });
  }

  const timestamp = Date.now();

  if (env.CONTACT_LOG) {
    const entry: ContactLogEntry = {
      ts: timestamp,
      email,
      subject,
      message
    };

    await env.CONTACT_LOG.put(`msg-${timestamp}`, JSON.stringify(entry));
  }

  if (!env.RESEND_API_KEY) {
    return new Response("Resend API key not configured", { status: 500 });
  }

  const normalizedSubject = normalizeSubject(subject);
  const truncatedSubject =
    normalizedSubject.length > RESEND_SUBJECT_SLICE_LENGTH
      ? normalizedSubject.slice(0, RESEND_SUBJECT_SLICE_LENGTH).trimEnd()
      : normalizedSubject;
  const composedSubject = `${EMAIL_SUBJECT_PREFIX}${truncatedSubject}`;
  const htmlMessage = escapeHtml(message).replace(/\r?\n/g, "<br>");

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
      <p><strong>From:</strong> ${escapeHtml(email)}</p>
      <p><strong>Subject:</strong> ${escapeHtml(normalizedSubject)}</p>
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

  if (!resp.ok) {
    let errorDetail = "";

    try {
      const errorJson = (await resp.json()) as ResendErrorResponse;
      errorDetail = errorJson?.message ?? JSON.stringify(errorJson);
    } catch {
      errorDetail = await resp.text();
    }

    console.error("Resend error:", resp.status, errorDetail);
    return new Response(`Error sending email: ${resp.status} ${errorDetail}`, {
      status: 500
    });
  }

  return new Response(null, {
    status: 303,
    headers: { Location: "/contact/sent" }
  });
};

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function isValidEmail(address: string): boolean {
  return Boolean(address) && address.length <= MAX_EMAIL_LENGTH && EMAIL_REGEX.test(address);
}

function isValidSubject(subject: string): boolean {
  if (!subject) {
    return false;
  }

  const trimmed = subject.trim();

  if (!trimmed || trimmed.length > MAX_SUBJECT_LENGTH) {
    return false;
  }

  return !/[<>]/.test(trimmed);
}

function normalizeSubject(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

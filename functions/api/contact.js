export async function onRequestPost({ request, env }) {
  const form = await request.formData();

  const email = form.get("email");
  const message = form.get("message");
  const nickname = form.get("nickname");
  const turnstileToken = form.get("cf-turnstile-response");

  // Honeypot spam filter
  if (nickname) {
    return Response.redirect("/contact/sent", 301);
  }

  if (!email || !message) {
    return new Response("Missing fields", { status: 400 });
  }

  // Validate Turnstile
  const turnstileResp = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    body: new URLSearchParams({
      secret: env.TURNSTILE_SECRET_KEY,
      response: turnstileToken
    })
  });

  const turnstileResult = await turnstileResp.json();

  if (!turnstileResult.success) {
    return new Response("Turnstile validation failed", { status: 400 });
  }

  // Save submission to KV (optional)
  const logEntry = {
    ts: Date.now(),
    email,
    message
  };

  if (env.CONTACT_LOG) {
    await env.CONTACT_LOG.put(`msg-${Date.now()}`, JSON.stringify(logEntry));
  }

  // Build MailChannels message
  const payload = {
    personalizations: [
      { to: [{ email: "steveng57@outlook.com" }] }
    ],
    from: { email: "noreply@stevengoulet.com" },
    subject: "New Contact Form Message",
    content: [
      {
        type: "text/plain",
        value: `New submission from stevengoulet.com\n\nFrom: ${email}\n\nMessage:\n${message}`
      }
    ]
  };

  const resp = await fetch("https://api.mailchannels.net/tx/v1/send", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });

  if (!resp.ok) {
    return new Response("Error sending email.", { status: 500 });
  }

  // Redirect to confirmation page
  return Response.redirect("/contact/sent", 302);
}

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
  if (!turnstileToken) {
    return new Response("Turnstile token missing", { status: 400 });
  }

  if (!env.TURNSTILE_SECRET_KEY) {
    return new Response("Turnstile secret key not configured", { status: 500 });
  }

  const turnstileResp = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    body: new URLSearchParams({
      secret: env.TURNSTILE_SECRET_KEY,
      response: turnstileToken
    })
  });

  const turnstileResult = await turnstileResp.json();

  if (!turnstileResult.success) {
    console.error("Turnstile validation failed:", turnstileResult);
    return new Response(`Turnstile validation failed: ${turnstileResult['error-codes']?.join(', ') || 'Unknown error'}`, { status: 400 });
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
    from: { 
      email: "noreply@stevengoulet.com",
      name: "Steven Goulet Website"
    },
    reply_to: {
      email: email,
      name: "Website Visitor"
    },
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
    let errorText = await resp.text();
    try {
        const json = JSON.parse(errorText);
        if (json.errors) {
            errorText = json.errors.map(e => e.message).join(", ");
        }
    } catch (e) {
        // ignore JSON parse error
    }
    console.error("MailChannels error:", resp.status, errorText);
    return new Response(`Error sending email: ${resp.status} ${errorText}`, { status: 500 });
  }

  // Redirect to confirmation page
  return Response.redirect("/contact/sent", 302);
}

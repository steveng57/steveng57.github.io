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

  const turnstileResult = await turnstileResp.json();

  if (!turnstileResult.success) {
    console.error("Turnstile validation failed:", turnstileResult);
    return new Response(
      `Turnstile validation failed: ${
        turnstileResult["error-codes"]?.join(", ") || "Unknown error"
      }`,
      { status: 400 }
    );
  }

  // Optional KV logging
  if (env.CONTACT_LOG) {
    await env.CONTACT_LOG.put(
      `msg-${Date.now()}`,
      JSON.stringify({
        ts: Date.now(),
        email,
        message
      })
    );
  }

  // Outbound email payload
  const payload = {
    personalizations: [
      {
        to: [
          {
            email: "steveng57@outlook.com",
            name: "Steven Goulet"
          }
        ]
      }
    ],
    from: {
      email: "noreply@stevengoulet.com",
      name: "Steven Goulet Website"
    },
    reply_to: {
      email: email,
      name: "Website Visitor"
    },
    subject: "New Contact Form Submission",
    content: [
      {
        type: "text/plain",
        value: `New message from stevengoulet.com

From: ${email}

Message:
${message}`
      },
      {
        type: "text/html",
        value: `
          <h2>New message from stevengoulet.com</h2>
          <p><strong>From:</strong> ${email}</p>
          <p><strong>Message:</strong></p>
          <p>${escapeHtml(message).replace(/\n/g, "<br>")}</p>
        `
      }
    ]
  };

  // Send through MailChannels
  const resp = await fetch("https://api.mailchannels.net/tx/v1/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
      // DO NOT include X-AuthUser — Cloudflare already authenticates you
    },
    body: JSON.stringify(payload)
  });

  if (!resp.ok) {
    let errorText = await resp.text();
    console.error("MailChannels error:", resp.status, errorText);
    return new Response(
      `Error sending email: ${resp.status} ${errorText}`,
      { status: 500 }
    );
  }

  return Response.redirect("/contact/sent", 302);
}

// Prevent HTML injection in emails
function escapeHtml(str) {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

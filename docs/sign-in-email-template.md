# Sign-in email with both a link and a code

In Supabase, go to **Authentication > Emails**. Paste the matching template into each of these two tabs, then click **Save**.

## Magic Link

Subject: `Your Macrotel sign-in link and code`

```html
<h2>Sign in to Macrotel</h2>
<p>Tap the button to sign in on this device:</p>
<p><a href="{{ .ConfirmationURL }}">Sign in</a></p>
<p>Or type this 6-digit code on the sign-in screen:</p>
<p style="font-size:28px;font-weight:bold;letter-spacing:6px">{{ .Token }}</p>
<p>The link and code expire in 1 hour. If you didn't ask to sign in, you can ignore this email.</p>
```

## Confirm signup

A first-time guest who signs in with a link or a code gets this email, so it needs the code too.

Subject: `Confirm your Macrotel account`

```html
<h2>Welcome to Macrotel</h2>
<p>Tap the button to confirm your email and sign in:</p>
<p><a href="{{ .ConfirmationURL }}">Confirm and sign in</a></p>
<p>Or type this 6-digit code on the sign-in screen:</p>
<p style="font-size:28px;font-weight:bold;letter-spacing:6px">{{ .Token }}</p>
```

Check under **Authentication > Providers > Email** that the **Email OTP Length** is set to 6.

const http = require('http');
const https = require('https');
const nodemailer = require('nodemailer');
const fs = require('fs');
const path = require('path');

// Load .env if present
try {
  const envPath = path.resolve(__dirname, '.env');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    envContent.split('\n').forEach(line => {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith('#')) {
        const [key, ...values] = trimmed.split('=');
        if (key && values.length > 0) {
          process.env[key.trim()] = values.join('=').trim();
        }
      }
    });
  }
} catch (e) {
  console.log('Error reading .env:', e.message);
}

const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true,
  auth: {
    user: process.env.GMAIL_USER || 'piggytrunk@gmail.com',
    pass: process.env.GMAIL_APP_PASSWORD || '',
  },
});

function sendViaResend(to, subject, html) {
  return new Promise((resolve, reject) => {
    const resendApiKey = process.env.RESEND_API_KEY || '';
    const fromEmail = process.env.RESEND_FROM_EMAIL || 'Piggy Trunk Support <support@piggytrunk.site>';

    const postData = JSON.stringify({
      from: fromEmail,
      to: Array.isArray(to) ? to : [to],
      subject: subject,
      html: html,
    });

    const req = https.request({
      hostname: 'api.resend.com',
      path: '/emails',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
      },
    }, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(JSON.parse(body));
          } catch (_) {
            resolve({ id: body });
          }
        } else {
          reject(new Error(`Resend error (${res.statusCode}): ${body}`));
        }
      });
    });

    req.on('error', err => reject(err));
    req.write(postData);
    req.end();
  });
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Private-Network', 'true');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  if (req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', async () => {
      try {
        const { to, subject, html } = JSON.parse(body || '{}');
        if (!to || !subject || !html) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Missing to, subject, or html' }));
          return;
        }

        // Try Resend primary first (authenticated via verified domain piggytrunk.site)
        try {
          const resendResult = await sendViaResend(to, subject, html);
          console.log(`[Piggy Trunk Bridge] Email sent via Resend to ${to} (ID: ${resendResult.id})`);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: true, provider: 'resend', id: resendResult.id }));
          return;
        } catch (resendErr) {
          console.warn('[Piggy Trunk Bridge] Resend failed, falling back to Gmail SMTP:', resendErr.message);
        }

        // Fallback to Gmail SMTP via nodemailer
        const info = await transporter.sendMail({
          from: 'Piggy Trunk Support <piggytrunk@gmail.com>',
          to,
          subject,
          html,
        });

        console.log(`[Piggy Trunk Bridge] Email sent via Gmail SMTP to ${to} (${info.messageId})`);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, provider: 'gmail_smtp', messageId: info.messageId }));
      } catch (err) {
        console.error('[Piggy Trunk Bridge Error]', err);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: err.message }));
      }
    });
  } else {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('Piggy Trunk Dual-Engine Email Bridge (Resend + Gmail SMTP) is running.');
  }
});

const PORT = 3001;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Piggy Trunk Email Bridge running on http://localhost:${PORT}`);
});

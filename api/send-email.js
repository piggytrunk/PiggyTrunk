const nodemailer = require('nodemailer');
const https = require('https');

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
          reject(new Error(`Resend API error (${res.statusCode}): ${body}`));
        }
      });
    });

    req.on('error', err => reject(err));
    req.write(postData);
    req.end();
  });
}

module.exports = async (req, res) => {
  // CORS configuration
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed. Use POST.' });
  }

  try {
    const { to, subject, html } = req.body || {};

    if (!to || !subject || !html) {
      return res.status(400).json({ error: 'Missing required parameters: to, subject, html' });
    }

    // 1. Try Resend verified custom domain first
    try {
      const resendRes = await sendViaResend(to, subject, html);
      return res.status(200).json({
        success: true,
        provider: 'resend',
        id: resendRes.id,
      });
    } catch (resendError) {
      console.warn('Resend failed on Vercel, falling back to Gmail SMTP:', resendError.message);
    }

    // 2. Fallback to Gmail SMTP
    const mailOptions = {
      from: 'Piggy Trunk Support <piggytrunk@gmail.com>',
      to,
      subject,
      html,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log('Email sent successfully via Gmail SMTP on Vercel:', info.messageId);

    return res.status(200).json({
      success: true,
      provider: 'gmail_smtp',
      message: 'Email delivered successfully',
      messageId: info.messageId,
    });
  } catch (error) {
    console.error('Error sending email on Vercel:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Internal server error while sending email',
    });
  }
};


import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const GEMINI_MODEL = "gemini-3.1-flash-lite";
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metode request tidak didukung." }, 405);
  }

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY");

    if (!apiKey) {
      console.error("Secret GEMINI_API_KEY belum tersedia.");
      return jsonResponse({ error: "Konfigurasi layanan AI belum tersedia." }, 500);
    }

    let body: {
      message?: string;
      imageBase64?: string;
      mimeType?: string;
    };

    try {
      body = await req.json();
    } catch {
      return jsonResponse({ error: "Format request tidak valid." }, 400);
    }

    const message = typeof body.message === "string"
      ? body.message.trim()
      : "";

    const imageBase64 = typeof body.imageBase64 === "string"
      ? body.imageBase64.replace(/^data:image\/[^;]+;base64,/, "")
      : "";

    const mimeType = body.mimeType ?? "";

    if (!message && !imageBase64) {
      return jsonResponse({
        error: "Tuliskan pertanyaan atau pilih gambar terlebih dahulu.",
      }, 400);
    }

    if (message.length > 10000) {
      return jsonResponse({ error: "Pertanyaan terlalu panjang." }, 400);
    }

    const parts: Array<Record<string, unknown>> = [];

    if (imageBase64) {
      const allowedMimeTypes = [
        "image/jpeg",
        "image/png",
        "image/webp",
      ];

      if (!allowedMimeTypes.includes(mimeType)) {
        return jsonResponse({
          error: "Format gambar harus JPG, PNG, atau WebP.",
        }, 400);
      }

      if (!/^[A-Za-z0-9+/]*={0,2}$/.test(imageBase64)) {
        return jsonResponse({ error: "Data gambar tidak valid." }, 400);
      }

      const estimatedBytes = Math.floor(imageBase64.length * 3 / 4);

      if (estimatedBytes > MAX_IMAGE_BYTES) {
        return jsonResponse({
          error: "Ukuran gambar maksimal 5 MB.",
        }, 413);
      }

      parts.push({
        inlineData: {
          mimeType,
          data: imageBase64,
        },
      });
    }

    parts.push({
      text: message ||
        "Jelaskan gambar ini dalam konteks perjalanan atau ibadah Umrah dan Haji. Jika konteksnya tidak berkaitan, jelaskan isi gambar secara umum dan tanyakan apa yang ingin diketahui pengguna.",
    });

    const systemPrompt =
      "Kamu adalah SafarMate AI, asisten berbahasa Indonesia yang membantu pengguna memahami persiapan perjalanan, Umrah, dan Haji. " +
      "Jawab dengan ramah, jelas, sederhana, dan terstruktur. " +
      "Untuk pertanyaan ibadah, gunakan penjelasan yang hati-hati dan jangan mengarang dalil, kutipan, atau ketentuan. " +
      "Jika terdapat perbedaan pendapat, jelaskan secara netral dan sarankan pengguna berkonsultasi dengan pembimbing ibadah yang tepercaya. " +
      "Jangan mengaku sebagai ustaz atau otoritas agama. " +
      "Jika gambar tidak jelas, sampaikan keterbatasannya dan jangan menebak informasi penting. " +
      "Jangan menganggap semua gambar berkaitan dengan ibadah. " +
      "Untuk informasi yang bergantung pada peraturan terbaru, sampaikan bahwa pengguna perlu memverifikasinya melalui sumber resmi.";

    const maxAttempts = 2;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      console.log(`Gemini request ${attempt}/${maxAttempts}`);

      let response: Response;

      try {
        response = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": apiKey,
            },
            body: JSON.stringify({
              systemInstruction: {
                parts: [{ text: systemPrompt }],
              },
              contents: [{
                role: "user",
                parts,
              }],
              generationConfig: {
                temperature: 0.5,
                maxOutputTokens: 1024,
              },
            }),
            signal: AbortSignal.timeout(30000),
          },
        );
      } catch (error) {
        console.error(`Gemini fetch error attempt ${attempt}:`, error);

        if (attempt < maxAttempts) {
          await new Promise((resolve) => setTimeout(resolve, 1000));
          continue;
        }

        return jsonResponse({
          error: "Gemini tidak dapat dijangkau. Silakan coba lagi.",
        }, 502);
      }

      const raw = await response.text();
      let result: any = null;

      try {
        result = JSON.parse(raw);
      } catch {
        console.error("Respons Gemini bukan JSON:", raw.slice(0, 500));
      }

      if (response.ok) {
        const answer = result?.candidates?.[0]?.content?.parts
          ?.map((part: { text?: string }) => part.text ?? "")
          .join("")
          .trim();

        if (!answer) {
          console.error("Gemini tidak menghasilkan teks jawaban.");
          return jsonResponse({
            error: "AI tidak menghasilkan jawaban.",
          }, 502);
        }

        return jsonResponse({ answer });
      }

      console.error(
        `Gemini status ${response.status}, attempt ${attempt}/${maxAttempts}:`,
        raw.slice(0, 1000),
      );

      const retryable = [429, 500, 502, 503, 504].includes(
        response.status,
      );

      if (!retryable || attempt === maxAttempts) {
        return jsonResponse({
          error: "Layanan AI gagal memproses pertanyaan.",
          code: response.status === 503
            ? "MODEL_UNAVAILABLE"
            : response.status === 429
            ? "RATE_LIMITED"
            : "GEMINI_ERROR",
        }, 502);
      }

      await new Promise((resolve) => setTimeout(resolve, attempt * 1500));
    }

    return jsonResponse({
      error: "Layanan AI gagal memproses pertanyaan.",
    }, 502);
  } catch (error) {
    console.error("SafarMate AI error:", error);

    return jsonResponse({
      error: "Terjadi kesalahan saat memproses pertanyaan.",
    }, 500);
  }
});

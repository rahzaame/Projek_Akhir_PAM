
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const GEMINI_MODEL = "gemini-3.1-flash-lite";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return Response.json(
      { error: "Method not allowed" },
      { status: 405, headers: corsHeaders },
    );
  }

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY");

    if (!apiKey) {
      console.error("GEMINI_API_KEY belum dikonfigurasi.");
      return Response.json(
        { error: "Konfigurasi API key belum tersedia." },
        { status: 500, headers: corsHeaders },
      );
    }

    const body = await req.json();
    const message = body?.message;

    if (typeof message !== "string" || !message.trim()) {
      return Response.json(
        { error: "Pesan tidak boleh kosong." },
        { status: 400, headers: corsHeaders },
      );
    }

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
                parts: [{
                  text: "Kamu adalah asisten informasi perjalanan umrah dalam aplikasi SafarMate. Jawab langsung inti pertanyaan pengguna tanpa mengawali jawaban dengan sapaan, perkenalan diri, atau mengulang nama SafarMate AI. Gunakan bahasa Indonesia yang ramah, jelas, alami, dan terstruktur. Gunakan judul, daftar, dan teks tebal jika membantu keterbacaan. Untuk pertanyaan ibadah, berikan informasi yang hati-hati dan jangan mengarang dalil. Jika informasi belum pasti atau bergantung pada peraturan terbaru, sampaikan bahwa pengguna perlu memverifikasinya melalui sumber resmi.",
                }],
              },
              contents: [{
                role: "user",
                parts: [{ text: message.trim() }],
              }],
              generationConfig: {
                temperature: 0.5,
                maxOutputTokens: 1024,
              },
            }),
            signal: AbortSignal.timeout(20000),
          },
        );
      } catch (error) {
        console.error(`Gemini fetch error attempt ${attempt}:`, error);

        if (attempt < maxAttempts) {
          await new Promise((resolve) =>
            setTimeout(resolve, 1000)
          );
          continue;
        }

        return Response.json(
          { error: "Gemini tidak dapat dijangkau. Silakan coba lagi." },
          { status: 502, headers: corsHeaders },
        );
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
          return Response.json(
            { error: "AI tidak menghasilkan jawaban." },
            { status: 502, headers: corsHeaders },
          );
        }

        return Response.json({ answer }, { headers: corsHeaders });
      }

      console.error(
        `Gemini status ${response.status}, attempt ${attempt}/${maxAttempts}:`,
        raw.slice(0, 1000),
      );

      const retryable = [429, 500, 502, 503, 504].includes(
        response.status,
      );

      if (!retryable || attempt === maxAttempts) {
        return Response.json(
          {
            error: "Layanan AI gagal memproses pertanyaan.",
            code: response.status === 503
              ? "MODEL_UNAVAILABLE"
              : response.status === 429
              ? "RATE_LIMITED"
              : "GEMINI_ERROR",
          },
          { status: 502, headers: corsHeaders },
        );
      }

      await new Promise((resolve) =>
        setTimeout(resolve, attempt * 1500)
      );
    }

    return Response.json(
      { error: "Layanan AI gagal memproses pertanyaan." },
      { status: 502, headers: corsHeaders },
    );
  } catch (error) {
    console.error("SafarMate AI error:", error);

    return Response.json(
      { error: "Terjadi kesalahan saat memproses pertanyaan." },
      { status: 500, headers: corsHeaders },
    );
  }
});

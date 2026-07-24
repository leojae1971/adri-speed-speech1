class ApiConfig {
  static const String backendBaseUrl = 'https://adri-speed-speech-backend.onrender.com';

  // FIX: 10s era demasiado corto. Un cold-start real de Render (free
  // tier) puede tardar 30-50s, y el backend en sí intenta varios
  // proveedores LLM en cadena antes de responder. 10s cortaba la
  // conexión ANTES de que el backend terminara, mostrando siempre el
  // mensaje de "no entendí" aunque el servidor sí hubiera respondido
  // un segundo más tarde.
  static const int requestTimeoutSeconds = 45;
}

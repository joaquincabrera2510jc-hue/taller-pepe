// ====== CONFIGURACIÓN — completar con los datos del proyecto de Supabase de Taller Pepe ======
// Supabase > Project Settings > API (o "Connect"):
//   "Project URL"            -> SUPABASE_URL
//   "anon public" (API key)  -> SUPABASE_ANON_KEY
// La clave "anon" es pública por diseño: los datos los protegen los permisos de la base.
// NUNCA pongas acá la clave "service_role".
window.CONFIG = {
  SUPABASE_URL: "https://yzdgzaeybuzxcalvnppp.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl6ZGd6YWV5YnV6eGNhbHZucHBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0ODA3NDUsImV4cCI6MjEwODA1Njc0NX0.hZCJ__tKVZpFeZJG8bmmhjNINp3eOyX-kpqNWsU7BH0",
  // Dominio interno de los usuarios (no se mandan correos): el usuario "pepe" es pepe@tallerpepe.local
  DOMINIO_USUARIOS: "tallerpepe.local",
  // Dirección del portal web de clientes
  PORTAL_URL: "https://joaquincabrera2510jc-hue.github.io/taller-pepe/",
};

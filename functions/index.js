// index.js (Corregido y Formateado)

// Importa los módulos necesarios
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
// CORRECCIÓN: Importar HttpsError para v2
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

// Inicializa Firebase Admin SDK (solo una vez)
admin.initializeApp();

/**
 * Cloud Function que se activa cuando un ciclo de planta termina.
 * Incrementa las horas acumuladas en la colección 'estaciones'.
 */
exports.actualizarHorasPlanta = onDocumentUpdated(
    "fallas_electricas/{fallaId}/ciclos_planta/{cicloId}",
    async (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();
      const {fallaId, cicloId} = event.params;

      if (
        beforeData.estadoCiclo !== "finalizado" &&
      afterData.estadoCiclo === "finalizado"
      ) {
        logger.log(`Ciclo ${cicloId} finalizado. Actualizando horas.`);

        const duracionMinutos = afterData.duracionCicloMinutos;
        if (typeof duracionMinutos !== "number" || duracionMinutos <= 0) {
          logger.error(
              "Duración del ciclo inválida o no encontrada:",
              duracionMinutos,
          );
          return;
        }

        const duracionHoras = duracionMinutos / 60;

        // Leer documento padre de la falla
        let fallaDoc;
        try {
          fallaDoc = await admin.firestore()
              .collection("fallas_electricas")
              .doc(fallaId)
              .get();
        } catch (error) {
          logger.error(`Error al leer la falla ${fallaId}:`, error);
          return;
        }
        if (!fallaDoc.exists) {
          logger.error("No se encontró el documento padre de la falla:", fallaId);
          return;
        }

        const fallaData = fallaDoc.data();
        const nombreEstacion = fallaData.estacion;
        if (!nombreEstacion) {
          logger.error("El documento de falla no tiene el campo 'estacion'.");
          return;
        }

        const estacionDocId = getEstacionDocIdFromName(nombreEstacion);
        if (!estacionDocId) {
          logger.error(
              "No se pudo determinar el ID para la estación:",
              nombreEstacion,
          );
          return;
        }

        try {
          await admin.firestore().collection("estaciones").doc(estacionDocId)
              .update({
                horasAcumuladas: admin.firestore.FieldValue.increment(duracionHoras),
              });
          logger.log(
              `Horas para ${nombreEstacion} (ID: ${estacionDocId}) ` +
          `incrementadas en ${duracionHoras.toFixed(2)}.`,
          );
        } catch (error) {
          logger.error(
              `Error al actualizar horasAcumuladas para ${estacionDocId}:`,
              error,
          );
        }
      } else {
        logger.log(
            `Actualización en ciclo ${cicloId} no relevante para horas.`,
        );
      }
    },
);

/**
 * Crea un nuevo usuario en Auth, le asigna un rol (Custom Claim)
 * y guarda su perfil en Firestore.
 * Esta función es llamada desde la app por un Superusuario.
 */
exports.crearUsuarioConRol = onCall(async (request) => {
  // 1. Verificación de Seguridad CRUCIAL
  if (request.auth.token.role !== "superusuario") {
    logger.warn(
        "Intento no autorizado para crear usuario por:",
        request.auth.uid,
    );
    // CORRECCIÓN: Usar HttpsError directamente
    throw new HttpsError(
        "permission-denied",
        "Solo los superusuarios pueden crear cuentas.",
    );
  }

  // 2. Obtener datos enviados desde la app
  const {
    identificador,
    password,
    nombre,
    rol,
    estacionAsignada,
    telefonoPersonal,
  } = request.data;

  // 3. Validar datos básicos
  if (!identificador || !password || !nombre || !rol || !estacionAsignada) {
    // CORRECCIÓN: Usar HttpsError directamente
    throw new HttpsError(
        "invalid-argument",
        "Faltan datos (identificador, password, nombre, rol, estacion).",
    );
  }

  // 4. Construir el email placeholder
  const email = identificador.trim().toLowerCase() + "@placeholder.corat.mx";

  try {
    // 5. Crear usuario en Firebase Authentication
    logger.log(`Creando usuario Auth para: ${email}`);
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: nombre,
    });
    const uid = userRecord.uid;
    logger.log(`Usuario Auth creado con UID: ${uid}`);

    // 6. Asignar Rol (Custom Claim)
    await admin.auth().setCustomUserClaims(uid, {role: rol});
    logger.log(`Claim '${rol}' asignado a ${uid}`);

    // 7. Guardar perfil en la colección 'usuarios' de Firestore
    const userProfile = {
      nombre: nombre,
      email: email, // Guardamos el placeholder por ahora
      rol: rol,
      estacionesPermitidas: [estacionAsignada], // Guardado como array
      telefonoPersonal: telefonoPersonal || null,
      isFirstLogin: true, // ¡Importante para el flujo de primer login!
      uid: uid, // Guardamos el UID para referencia
    };

    await admin.firestore().collection("usuarios").doc(uid).set(userProfile);
    logger.log(`Perfil de Firestore creado para ${uid}`);

    // 8. Devolver éxito a la app
    return {success: true, uid: uid, email: email};
  } catch (error) {
    logger.error("Error al crear usuario:", error);

    // Manejar errores comunes
    if (error.code === "auth/email-already-exists") {
      // CORRECCIÓN: Usar HttpsError directamente
      throw new HttpsError(
          "already-exists",
          `El email placeholder '${email}' (basado en el identificador) ` +
        "ya existe.",
      );
    }
    // CORRECCIÓN: Usar HttpsError directamente
    throw new HttpsError(
        "internal",
        "Ocurrió un error en el servidor al crear el usuario.",
    );
  }
});

/**
 * Obtiene el ID del documento Firestore a partir del nombre de la estación.
 * @param {string} nombreEstacion Nombre completo de la estación.
 * @return {string|null} ID del documento o null si no se reconoce.
 */
function getEstacionDocIdFromName(nombreEstacion) {
  const lowerName = nombreEstacion.toLowerCase();
  if (lowerName.includes("boca")) return "boca_del_cerro";
  if (lowerName.includes("cunduacan")) return "cunduacan";
  if (lowerName.includes("periferico")) return "periferico_vh";
  if (lowerName.includes("rancho")) return "rancho_grande";
  if (lowerName.includes("venta")) return "la_venta";
  console.warn("Nombre de estación no reconocido:", nombreEstacion);
  return null;
}

// Línea vacía final

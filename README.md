# Gestor de Tareas (Node.js + Express)

Esta aplicación es un gestor de tareas (Todo List) construido con Node.js, Express y EJS para el renderizado, con estilos modernos utilizando Tailwind CSS.

## Requisitos Previos

- Node.js (v18 o superior)
- npm

## Instalación

1. Clona el repositorio si no lo has hecho.
2. Instala las dependencias:
   ```bash
   npm install
   ```

## Ejecución

Para iniciar la aplicación en modo desarrollo (con recarga automática y compilación de CSS):

```bash
npm run dev
```

La aplicación estará disponible en [http://localhost:3000](http://localhost:3000).

## Pruebas (Tests)

Se han implementado tests unitarios y de integración para asegurar el correcto funcionamiento del modelo y las rutas:

```bash
npm test
```

---

# Manual de Uso

Este manual describe cómo administrar tus tareas utilizando la aplicación.

## 1. Interfaz Principal
Al abrir la aplicación, verás una interfaz limpia con un encabezado que indica "Gestiona tus tareas" y un campo de entrada para agregar nuevas tareas.

## 2. Agregar una Tarea
1. Escribe el título de tu tarea en el campo de texto que dice **"Añade una nueva tarea"**.
2. Haz clic en el botón **"Agregar"** o presiona la tecla `Enter`.
3. La tarea aparecerá inmediatamente en la lista superior (las más nuevas aparecen primero).

## 3. Marcar una Tarea como Completada
1. Ubica la tarea que deseas completar.
2. Haz clic en el **círculo** a la izquierda del título de la tarea.
3. El título de la tarea se tachará y el estado cambiará a **"Completada"**.
4. Puedes desmarcarla haciendo clic nuevamente en el círculo.

## 4. Eliminar una Tarea
1. Ubica la tarea que deseas borrar.
2. Haz clic en el botón **"Eliminar"** situado a la derecha de la tarea.
3. La tarea desaparecerá permanentemente de la lista.

---

## Estructura del Proyecto (Versión Node.js)

- `app.js`: Punto de entrada del servidor Express.
- `src/models/taskModel.js`: Lógica de datos y almacenamiento en memoria.
- `src/controllers/taskController.js`: Lógica de manejo de peticiones.
- `src/routes/taskRoutes.js`: Definición de rutas (endpoints).
- `views/index.ejs`: Plantilla de la interfaz de usuario.
- `tests/`: Directorio con las pruebas del sistema.

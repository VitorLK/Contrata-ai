const crypto = require('crypto');
const path = require('path');
const multer = require('multer');

const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads');
const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5MB

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    // Nome aleatório (não o nome original do arquivo do usuário) evita
    // colisão e path traversal.
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `${crypto.randomUUID()}${ext}`);
  },
});

function fileFilter(req, file, cb) {
  if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    return cb(new Error('Formato de imagem não suportado. Envie JPEG, PNG ou WEBP.'));
  }
  cb(null, true);
}

const upload = multer({ storage, fileFilter, limits: { fileSize: MAX_FILE_SIZE_BYTES } });

/**
 * Envolve upload.single(field) traduzindo erros do multer (arquivo grande
 * demais, formato não suportado) em respostas 400 amigáveis, em vez de
 * deixá-los cair no error handler genérico (500) do app.js.
 */
function handleUpload(field) {
  const middleware = upload.single(field);
  return (req, res, next) => {
    middleware(req, res, (err) => {
      if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
          return res.status(400).json({ error: 'Arquivo muito grande. O limite é 5MB.' });
        }
        return res.status(400).json({ error: 'Não foi possível processar o arquivo enviado.' });
      }
      if (err) {
        return res.status(400).json({ error: err.message });
      }
      next();
    });
  };
}

module.exports = { upload, handleUpload, UPLOAD_DIR };

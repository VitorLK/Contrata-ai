const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/authRoutes');
const serviceRoutes = require('./routes/serviceRoutes');
const applicationRoutes = require('./routes/applicationRoutes');
const professionalRoutes = require('./routes/professionalRoutes');
const workRoutes = require('./routes/workRoutes');
const locationRoutes = require('./routes/locationRoutes');
const adminRoutes = require('./routes/adminRoutes');
const chatRoutes = require('./routes/chatRoutes');
const { UPLOAD_DIR } = require('./middlewares/upload');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Serve as imagens enviadas (foto de perfil, portfólio) pelo mesmo caminho
// relativo que é salvo em photo_url/image_url no banco.
app.use('/uploads', express.static(UPLOAD_DIR));

app.use('/auth', authRoutes);
app.use('/services', serviceRoutes);
app.use('/applications', applicationRoutes);
app.use('/professionals', professionalRoutes);
app.use('/work', workRoutes);
app.use('/locations', locationRoutes);
app.use('/admin', adminRoutes);
app.use('/chat', chatRoutes);

app.use((req, res) => {
  res.status(404).json({ error: 'Rota não encontrada.' });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('Erro não tratado:', err);
  res.status(500).json({ error: 'Erro interno do servidor.' });
});

module.exports = app;

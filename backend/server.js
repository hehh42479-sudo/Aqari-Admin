const express = require('express');
const cors = require('cors');

const app = express();
const port = process.env.PORT || 8080;

app.use(cors());
app.use(express.json());

app.get('/api/admin/statistics', (req, res) => {
  res.json({
    totalUsers: 35,
    totalProperties: 124,
    pendingProperties: 19,
    totalSupervisors: 5,
    activeProperties: 105,
    featuredProperties: 12,
    monthlyRevenue: 35240,
  });
});

app.get('/api/admin/activity-logs', (req, res) => {
  res.json([]);
});

app.use((req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.originalUrl,
  });
});

app.listen(port, () => {
  console.log(`Aqari Admin mock API listening on port ${port}`);
});

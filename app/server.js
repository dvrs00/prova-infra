const http = require('http');
const { Client } = require('pg');

// As variáveis vêm do Docker Compose (Environment)
const dbConfig = {
  user: process.env.DB_USER || 'admin',
  host: process.env.DB_HOST,
  database: process.env.DB_NAME || 'prova-db',
  password: process.env.DB_PASS || 'admin', 
  port: 5432,
};

const server = http.createServer(async (req, res) => {
    // Log para ver no CloudWatch/Docker logs
    console.log(`[${new Date().toISOString()}] Request: ${req.method} ${req.url}`);

    if (req.url === '/health' || req.url === '/') {
        const client = new Client(dbConfig);
        let dbStatus = 'Tentando conectar...';
        let dados = [];

        try {
            await client.connect();
            // Traz dados reais para provar o requisito da prova
            const resDb = await client.query('SELECT * FROM usuarios');
            dados = resDb.rows;
            dbStatus = 'CONECTADO COM SUCESSO';
            await client.end();
        } catch (err) {
            dbStatus = 'ERRO DE CONEXAO: ' + err.message;
            console.error('DB Error:', err);
        }

        const response = {
            environment: 'Production (Terraform + CI/CD)',
            status_app: 'Online',
            status_db: dbStatus,
            data: dados
        };

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(response, null, 2));
    } else {
        res.writeHead(404);
        res.end('Not Found');
    }
});

server.listen(3000, () => {
    console.log('Server running on port 3000');
});
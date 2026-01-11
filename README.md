# 🚀 Desafio de Infraestrutura Cloud, Redes e Containers

Este repositório contém a solução para o desafio técnico de infraestrutura, implementando um ambiente funcional na AWS com segmentação de rede, containerização total e automação via Terraform e Azure DevOps.

## 📋 1. Descrição da Arquitetura

A infraestrutura foi desenhada seguindo as melhores práticas de mercado (Three-Tier Architecture adaptado), garantindo segurança, alta disponibilidade e facilidade de gerenciamento.

* **Cloud Provider:** AWS (Free Tier elegível, com exceção do NAT Gateway).
* **Rede (VPC):**
    * **Subnet Pública:** Hospeda a camada de Apresentação/Proxy. Acessível via Internet Gateway.
    * **Subnet Privada:** Hospeda a camada de Dados. Sem acesso direto de entrada da internet (protegida), mas com saída via NAT Gateway para atualizações.
* **Componentes:**
    * **Proxy Reverso (Nginx):** Recebe o tráfego HTTP na porta 80 e encaminha internamente para a aplicação.
    * **Aplicação (Node.js):** API REST que consulta o banco de dados.
    * **Banco de Dados (PostgreSQL):** Isolado na rede privada, acessível apenas pela aplicação.
* **Fluxo de Dados:**
    `Cliente -> Cloudflare (DNS) -> EC2 Pública (Nginx -> Node App) -> EC2 Privada (Postgres)`

---

## 🛠️ 2. Instalação e Configuração

### Pré-requisitos
* Conta AWS ativa.
* Terraform instalado.
* Conta no Azure DevOps (com Pool de Agentes configurado).
* Docker Hub Account.

### Passo 1: CI/CD (Build da Aplicação)
O pipeline no **Azure DevOps** monitora a branch `main`.
1.  O commit dispara o pipeline no agente **Self-Hosted**.
2.  O Docker realiza o build da imagem baseado no `app/Dockerfile`.
3.  A imagem é enviada (Push) para o Docker Hub: `dvrsdev/douglasprovacloud:latest`.

### Passo 2: Provisionamento (Terraform)
A infraestrutura é 100% código (IaC).
1.  Acesse a pasta `infra/`.
2.  Inicialize o Terraform:
    ```bash
    terraform init
    ```
3.  Aplique a infraestrutura:
    ```bash
    terraform apply --auto-approve
    ```
    *Este comando provisiona VPC, Subnets, NAT Gateway, Security Groups e as EC2s. Os scripts de `user_data` configuram o Docker e sobem os containers automaticamente.*

### Passo 3: Configuração do DNS (Cloudflare)
1.  Após o provisionamento, capture o **Elastic IP** exibido no output do Terraform ou console AWS.
2.  O apontamento do domínio para o IP público da EC2 feito no Cloudflare, foi realizado pelo Lucas Cruz, com um domínio da uzzipay, conforme instruído na prova.
3.  O tráfego passará pelo proxy da Cloudflare antes de chegar na AWS.

---

## 💡 3. Decisões Técnicas e Justificativas

| Decisão | Justificativa |
| :--- | :--- |
| **Terraform (IaC)** | Inicialmente, a infraestrutura foi criada manualmente via Console AWS. Porém, a gestão de múltiplos recursos (VPC, SG, Subnets) tornou-se complexa e propensa a erros. Migrei para Terraform para ter controle total, permitindo criar e **destruir** o ambiente com um comando, facilitando a gestão de custos. |
| **NAT Gateway (Managed)** | Optei pelo NAT Gateway nativo da AWS em vez de uma "NAT Instance" manual. Embora tenha custo, é a prática de mercado para garantir estabilidade e escalabilidade sem necessidade de gerenciar patches de segurança de uma instância extra. O custo foi controlado destruindo o ambiente via Terraform após os testes. |
| **Agent Self-Hosted** | Devido às restrições recentes da Microsoft para "Parallel Jobs" em contas gratuitas (com liberação demorada), configurei um Agente Self-Hosted localmente para garantir que o pipeline de CI rodasse imediatamente, sem bloquear o progresso da prova. |
| **Nginx Containerizado** | Para cumprir rigorosamente o requisito de "Tudo containerizado" e garantir a imutabilidade da EC2. Se a instância for recriada, o Nginx sobe configurado automaticamente, sem intervenção manual. |

---

## ⚠️ 4. Problemas Encontrados e Soluções

### 1. Indisponibilidade de Agentes no Azure DevOps
* **Problema:** O pipeline falhava pois a conta gratuita do Azure DevOps não tinha *parallel jobs* liberados pela Microsoft (prazo de liberação era longo).
* **Solução:** Configurei um **Agente Self-Hosted** na minha própria máquina, conectando-o ao Azure DevOps. Isso permitiu fazer o build e push da imagem Docker sem depender da fila da Microsoft.

### 2. Gerenciamento e Limpeza de Recursos
* **Problema:** Ao iniciar a prova pelo Console AWS, perdi o rastreio de alguns recursos (Security Groups órfãos), dificultando a limpeza e gerando risco de cobrança desnecessária.
* **Solução:** Adotei o **Terraform**. Isso me deu confiança para usar recursos melhores (como o NAT Gateway) sabendo que um simples `terraform destroy` limparia 100% do ambiente, evitando surpresas na fatura.

### 3. Conectividade da Instância Privada
* **Problema:** A EC2 de Banco de Dados (Privada) não conseguia baixar o Docker e as imagens, pois não tinha IP público.
* **Solução:** Implementação do **NAT Gateway** na subnet pública e configuração das tabelas de rota (Route Tables) para permitir que a subnet privada tivesse saída para a internet, mantendo-se fechada para entrada.

### 4. Race Condition (App x Banco)
* **Problema:** O container da aplicação iniciava antes do banco estar pronto para aceitar conexões, gerando erro fatal.
* **Solução:** Adicionei lógica de *Retry* na aplicação Node.js e configurei `healthcheck` robusto no Docker Compose do banco.

---

## 🌐 5. Dados de Acesso e Evidências

* **URL da Aplicação:** `http://provadouglas.uzzipay.com`
* **Endpoint de Teste:** `/` ou `/health`

### Exemplo de Retorno JSON
```json
{
  "environment": "Production (Terraform + CI/CD)",
  "status_app": "Online",
  "status_db": "CONECTADO COM SUCESSO",
  "data": [
    {
      "id": 1,
      "nome": "Douglas",
      "cargo": "DevOps/NOC1",
      "situacao": "Aprovado"
    }
  ]
}
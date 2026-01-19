# Tarefa 02: Tabela de Processos SNMP

## Descrição
Implementação de uma tabela SNMP customizada para listar e monitorar processos em execução no sistema. Esta tarefa demonstra o uso de estruturas de dados complexas (tabelas) em MIBs SNMP.

## Funcionalidades

A tabela de processos fornece as seguintes informações para cada processo:

1. **PID** (Process ID) - Identificador único do processo
2. **Nome** - Nome do comando/executável
3. **CPU (%)** - Uso de CPU em percentual
4. **Memória (MB)** - Uso de memória RAM em Megabytes
5. **Uptime** - Tempo de execução no formato HH:MM:SS

## Arquivos

```
Tarefa02_Tabela_Processos/
├── PROCESS-TABLE-MIB.txt     # Definição da MIB
├── process_table_agent.sh     # Agente SNMP em bash
└── README.md                  # Esta documentação
```

## Instalação

### 1. Instalar Net-SNMP

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install snmpd snmp snmp-mibs-downloader
```

**RedHat/CentOS:**
```bash
sudo yum install net-snmp net-snmp-utils
```

**MacOS:**
```bash
brew install net-snmp
```

### 2. Copiar a MIB

**Linux:**
```bash
sudo cp PROCESS-TABLE-MIB.txt /usr/share/snmp/mibs/
# ou
mkdir -p ~/.snmp/mibs
cp PROCESS-TABLE-MIB.txt ~/.snmp/mibs/
```

**MacOS:**
```bash
mkdir -p ~/.snmp/mibs
cp PROCESS-TABLE-MIB.txt ~/.snmp/mibs/
```

### 3. Instalar o agente

```bash
# Copiar script para local apropriado
sudo cp process_table_agent.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/process_table_agent.sh
```

### 4. Configurar snmpd

Adicione a seguinte linha ao arquivo `/etc/snmp/snmpd.conf`:

```bash
pass_persist .1.3.6.1.4.1.99999.2 /usr/local/bin/process_table_agent.sh
```

**Nota:** O OID `.1.3.6.1.4.1.99999.2` corresponde ao `processTableMIB`.

### 5. Reiniciar snmpd

```bash
sudo systemctl restart snmpd

# Verificar se está rodando
sudo systemctl status snmpd
```

## Como Testar

### Teste 1: Listar todos os processos

```bash
# Listar toda a tabela
snmpwalk -v2c -c public localhost .1.3.6.1.4.1.99999.2

# Ou usando nome da MIB (mais legível)
snmpwalk -v2c -c public -m +PROCESS-TABLE-MIB localhost PROCESS-TABLE-MIB::processTable
```

**Saída esperada:**
```
PROCESS-TABLE-MIB::processPID.1 = INTEGER: 1
PROCESS-TABLE-MIB::processName.1 = STRING: "systemd"
PROCESS-TABLE-MIB::processCPU.1 = INTEGER: 0
PROCESS-TABLE-MIB::processMemory.1 = INTEGER: 15
PROCESS-TABLE-MIB::processUptime.1 = STRING: "125:34:21"
PROCESS-TABLE-MIB::processPID.475 = INTEGER: 475
PROCESS-TABLE-MIB::processName.475 = STRING: "snapd"
...
```

### Teste 2: Consultar processo específico por PID

```bash
# Exemplo: Consultar processo com PID 1 (systemd)
snmpget -v2c -c public localhost \
    .1.3.6.1.4.1.99999.2.1.1.1.1 \
    .1.3.6.1.4.1.99999.2.1.1.2.1 \
    .1.3.6.1.4.1.99999.2.1.1.3.1 \
    .1.3.6.1.4.1.99999.2.1.1.4.1 \
    .1.3.6.1.4.1.99999.2.1.1.5.1
```

Ou usando nomes (mais legível):
```bash
snmpget -v2c -c public -m +PROCESS-TABLE-MIB localhost \
    PROCESS-TABLE-MIB::processPID.1 \
    PROCESS-TABLE-MIB::processName.1 \
    PROCESS-TABLE-MIB::processCPU.1 \
    PROCESS-TABLE-MIB::processMemory.1 \
    PROCESS-TABLE-MIB::processUptime.1
```

### Teste 3: Filtrar apenas nomes de processos

```bash
snmpwalk -v2c -c public -m +PROCESS-TABLE-MIB localhost PROCESS-TABLE-MIB::processName
```

### Teste 4: Filtrar apenas uso de CPU

```bash
snmpwalk -v2c -c public -m +PROCESS-TABLE-MIB localhost PROCESS-TABLE-MIB::processCPU
```

### Teste 5: Filtrar apenas uso de memória

```bash
snmpwalk -v2c -c public -m +PROCESS-TABLE-MIB localhost PROCESS-TABLE-MIB::processMemory
```

### Teste 6: Monitoramento contínuo

```bash
# Atualizar a cada 5 segundos
watch -n 5 'snmpwalk -v2c -c public -m +PROCESS-TABLE-MIB localhost PROCESS-TABLE-MIB::processTable'
```

### Teste 7: Validar a MIB

```bash
# Verificar sintaxe
smilint -l 3 PROCESS-TABLE-MIB.txt

# Traduzir OID para nome
snmptranslate -m +PROCESS-TABLE-MIB -On PROCESS-TABLE-MIB::processTable

# Ver estrutura da tabela
snmptranslate -m +PROCESS-TABLE-MIB -Tp -IR processTableMIB
```

## Estrutura da Tabela

### OIDs

```
.1.3.6.1.4.1.99999.2           # processTableMIB
└── .1                          # processTable
    └── .1                      # processEntry
        ├── .1.[PID]            # processPID
        ├── .2.[PID]            # processName
        ├── .3.[PID]            # processCPU
        ├── .4.[PID]            # processMemory
        └── .5.[PID]            # processUptime
```

### Colunas da Tabela

| Coluna | OID | Tipo | Acesso | Descrição |
|--------|-----|------|--------|-----------|
| processPID | .1.3.6.1.4.1.99999.2.1.1.1 | Integer32 | read-only | Process ID (índice) |
| processName | .1.3.6.1.4.1.99999.2.1.1.2 | DisplayString | read-only | Nome do comando |
| processCPU | .1.3.6.1.4.1.99999.2.1.1.3 | Integer32 | read-only | % CPU (0-100) |
| processMemory | .1.3.6.1.4.1.99999.2.1.1.4 | Integer32 | read-only | Memória em MB |
| processUptime | .1.3.6.1.4.1.99999.2.1.1.5 | DisplayString | read-only | Tempo no formato HH:MM:SS |

## Exemplo de Saída Formatada

```bash
# Script para exibir de forma legível
snmpwalk -v2c -c public -m +PROCESS-TABLE-MIB localhost PROCESS-TABLE-MIB::processTable | \
awk '
/processPID/ {pid=$4}
/processName/ {name=$4; gsub(/"/, "", name)}
/processCPU/ {cpu=$4}
/processMemory/ {mem=$4}
/processUptime/ {uptime=$4; gsub(/"/, "", uptime); 
    printf "PID: %5s | Nome: %-20s | CPU: %3s%% | Mem: %5sMB | Uptime: %s\n", 
    pid, name, cpu, mem, uptime
}
'
```

**Resultado:**
```
PID:     1 | Nome: systemd              | CPU:   0% | Mem:    15MB | Uptime: 125:34:21
PID:   475 | Nome: snapd                | CPU:   0% | Mem:    45MB | Uptime: 125:30:15
PID:   892 | Nome: NetworkManager       | CPU:   1% | Mem:    32MB | Uptime: 125:25:10
PID:  1523 | Nome: gnome-shell          | CPU:  12% | Mem:   856MB | Uptime: 120:15:42
```

## Como Funciona

### Mecanismo pass_persist

1. **snmpd** recebe consulta SNMP
2. Identifica que o OID está delegado ao agente externo
3. Comunica com `process_table_agent.sh` via stdin/stdout
4. Agente responde com dados atualizados
5. **snmpd** retorna resposta ao cliente

### Protocolo de Comunicação

```
Cliente → snmpd: GETNEXT .1.3.6.1.4.1.99999.2
snmpd → agent: getnext
snmpd → agent: .1.3.6.1.4.1.99999.2
agent → snmpd: .1.3.6.1.4.1.99999.2.1.1.1.1
agent → snmpd: integer
agent → snmpd: 1
snmpd → Cliente: .1.3.6.1.4.1.99999.2.1.1.1.1 = INTEGER: 1
```

### Implementação do Agente

O script `process_table_agent.sh` implementa:

1. **Inicialização**: Responde "PING" → "PONG"
2. **GET**: Retorna valor específico de um OID
3. **GETNEXT**: Percorre a tabela ordenadamente
   - Lê processos com `ps aux`
   - Ordena por PID
   - Mantém estado da última consulta
   - Calcula tempo de uptime
   - Converte memória para MB

## Plataformas Suportadas

### Linux
✅ Totalmente funcional
- Usa `ps aux` padrão
- Lê `/proc/uptime` para calcular tempo de sistema

### MacOS
✅ Funcional com limitações
- `ps aux` funciona mas formato pode variar
- Alguns campos podem ter valores aproximados
- Tempo de sistema obtido via `sysctl kern.boottime`

### Windows (WSL)
⚠️ Parcialmente funcional
- Mostra processos do WSL, não do Windows host
- Recomenda-se usar ferramenta nativa Windows SNMP

## Troubleshooting

### Timeout ao consultar

```bash
# Verificar se snmpd está rodando
sudo systemctl status snmpd

# Verificar logs
sudo tail -f /var/log/syslog | grep snmp

# Testar agente diretamente
echo -e "PING\nget\n.1.3.6.1.4.1.99999.2.1.1.1.1" | /usr/local/bin/process_table_agent.sh
```

### Tabela vazia

```bash
# Verificar se ps funciona
ps aux | head

# Testar agente standalone
/usr/local/bin/process_table_agent.sh
# Digite: PING (Enter)
# Digite: getnext (Enter)  
# Digite: .1.3.6.1.4.1.99999.2 (Enter)
```

### MIB não carrega

```bash
# Verificar se arquivo existe
ls -l ~/.snmp/mibs/PROCESS-TABLE-MIB.txt

# Carregar explicitamente
export MIBS=+PROCESS-TABLE-MIB

# Testar tradução
snmptranslate -m +PROCESS-TABLE-MIB -On PROCESS-TABLE-MIB::processTable
```

### Agent não responde

```bash
# Verificar permissões
ls -l /usr/local/bin/process_table_agent.sh
chmod +x /usr/local/bin/process_table_agent.sh

# Verificar configuração snmpd
grep pass_persist /etc/snmp/snmpd.conf

# Reiniciar snmpd
sudo systemctl restart snmpd
```

### Valores incorretos

```bash
# Verificar formato do ps
ps aux | head -5

# Se formato diferir, ajustar variáveis no script:
# COLUMN_PID, COLUMN_CPU, COLUMN_MEM, COLUMN_TIME, COLUMN_CMD
```

## Melhorias Possíveis

1. **Filtros**: Adicionar objetos para filtrar processos por usuário ou nome
2. **Controle**: Permitir matar processos via SNMP SET
3. **Estatísticas**: Adicionar total de processos, média de CPU/memória
4. **Cache**: Implementar cache com TTL para melhor performance
5. **Threads**: Incluir informação de threads por processo

## Conceitos Aprendidos

1. **SEQUENCE**: Definição de estrutura de entrada de tabela
2. **INDEX**: Indexação de tabelas por PID
3. **GETNEXT**: Navegação ordenada em estruturas complexas
4. **DisplayString**: Tipo de string legível
5. **Integer32**: Tipo numérico de 32 bits
6. **MAX-ACCESS**: Controle de acesso (read-only)
7. **pass_persist**: Agentes externos persistentes

## Referências

- RFC 2578 - SMIv2 (Structure of Management Information)
- RFC 2579 - Textual Conventions (DisplayString, etc)
- RFC 2863 - The Interfaces Group MIB (exemplo de tabela)
- man snmpd.conf(5)
- man ps(1)

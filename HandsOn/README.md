# Hands On SNMP - Gerência de Redes

Implementação prática de conceitos de SNMP (Simple Network Management Protocol) para a disciplina de Gerência de Redes.

## Autores - MDCC/UFC


**João Batista Andrade  - batistajoaoguns@alu.ufc.br**
**Mayara Almeida        - mayaraalmeida@alu.ufc.br**
**Marcos Dantas Ortiz   - mdo@ufc.br**  



## Sobre o Projeto

Este projeto demonstra os principais conceitos de SNMP através de três tarefas práticas que exploram diferentes aspectos do protocolo:

1. **MIB Customizada para Controle** - Desenvolvimento de MIB e agente SNMP para controlar serviços
2. **Tabelas SNMP** - Implementação de tabelas para gerenciar informações estruturadas
3. **SNMP Traps** - Sistema de notificações assíncronas para alertas críticos

## Visão Geral das Tarefas

### Tarefa 01: MIB Customizada para Controle do snmpd

**Objetivo:** Criar uma MIB customizada que permite monitorar e controlar o serviço snmpd via SNMP.

**Conceitos Demonstrados:**
- Objetos escalares (single-instance objects)
- Operações GET e SET
- Agente pass_persist em bash
- Controle de serviço via SNMP

**Objetos da MIB (CUSTOM-CONTROL-MIB):**

| OID | Nome | Tipo | Acesso | Descrição |
|-----|------|------|--------|-----------|
| .1.3.6.1.4.1.99999.1.1.0 | snmpdStatus | INTEGER | READ-ONLY | Status atual do serviço snmpd<br/>1=running, 2=stopped, 3=unknown |
| .1.3.6.1.4.1.99999.1.2.0 | snmpdControl | INTEGER | READ-WRITE | Controle do serviço snmpd<br/>1=start, 2=stop, 3=restart, 4=status |

**Fluxo de Operação:**

```mermaid
sequenceDiagram
    participant Cliente as Cliente SNMP
    participant SNMPD as snmpd daemon
    participant Agent as snmpd_control_agent.sh
    participant System as systemctl
    
    Note over Cliente: Consultar status
    Cliente->>SNMPD: snmpget snmpdStatus.0
    SNMPD->>Agent: get .1.3.6.1.4.1.99999.1.1.0
    Agent->>System: systemctl is-active snmpd
    System-->>Agent: active
    Agent-->>SNMPD: INTEGER: 1 (running)
    SNMPD-->>Cliente: snmpdStatus.0 = 1
    
    Note over Cliente: Reiniciar serviço
    Cliente->>SNMPD: snmpset snmpdControl.0 = 3
    SNMPD->>Agent: set .1.3.6.1.4.1.99999.1.2.0 = 3
    Agent->>System: systemctl restart snmpd
    System-->>Agent: sucesso
    Agent-->>SNMPD: INTEGER: 3
    SNMPD-->>Cliente: snmpdControl.0 = 3
```

**Arquitetura do Cenário:**

```mermaid
graph LR
    subgraph "Cliente SNMP"
        CLI["snmpget/snmpset<br/>porta origem aleatoria"]
    end
    
    subgraph "Servidor SNMP - porta 161"
        SNMPD["snmpd daemon<br/>Master Agent"]
        CONFIG["snmpd.conf<br/>pass_persist config"]
    end
    
    subgraph "Agente Externo"
        AGENT["snmpd_control_agent.sh<br/>Protocol: stdin/stdout"]
    end
    
    subgraph "Sistema Operacional"
        SYSTEMD["systemctl<br/>Service Manager"]
        SERVICE["snmpd.service"]
    end
    
    CLI -->|SNMPv2c UDP 161| SNMPD
    SNMPD -.->|carrega| CONFIG
    SNMPD <-->|pipe stdin/stdout| AGENT
    AGENT -->|systemctl commands| SYSTEMD
    SYSTEMD -->|gerencia| SERVICE
    
    style CLI fill:#a8dadc
    style SNMPD fill:#95e1d3
    style AGENT fill:#ffe66d
    style SYSTEMD fill:#ff6b6b
```

---

### Tarefa 02: Tabela SNMP de Processos

**Objetivo:** Implementar uma tabela SNMP que lista processos do sistema com informações de CPU, memória e uptime.

**Conceitos Demonstrados:**
- Estruturas de tabelas SNMP
- Indexação de tabelas (processPID como INDEX)
- Operação GETNEXT para travessia de tabela
- Parse de saída do comando `ps`

**Objetos da MIB (PROCESS-TABLE-MIB):**

| OID | Nome | Tipo | Acesso | Descrição |
|-----|------|------|--------|-----------|
| .1.3.6.1.4.1.99999.2.1.1 | processTable | SEQUENCE | not-accessible | Tabela de processos |
| .1.3.6.1.4.1.99999.2.1.1.1 | processEntry | SEQUENCE | not-accessible | Entrada da tabela (uma linha) |
| .1.3.6.1.4.1.99999.2.1.1.1.1.{PID} | processPID | INTEGER | READ-ONLY | Process ID (INDEX) |
| .1.3.6.1.4.1.99999.2.1.1.1.2.{PID} | processName | OCTET STRING | READ-ONLY | Nome do processo |
| .1.3.6.1.4.1.99999.2.1.1.1.3.{PID} | processCPU | OCTET STRING | READ-ONLY | Uso de CPU (%) |
| .1.3.6.1.4.1.99999.2.1.1.1.4.{PID} | processMemory | OCTET STRING | READ-ONLY | Uso de memória (%) |
| .1.3.6.1.4.1.99999.2.1.1.1.5.{PID} | processUptime | OCTET STRING | READ-ONLY | Tempo de execução |

**Exemplo de Dados:**

```
processPID.1234 = 1234
processName.1234 = "apache2"
processCPU.1234 = "2.5"
processMemory.1234 = "1.8"
processUptime.1234 = "3-04:23:15"

processPID.5678 = 5678
processName.5678 = "mysql"
processCPU.5678 = "15.3"
processMemory.5678 = "8.2"
processUptime.5678 = "1-02:15:30"
```

**Fluxo de Consulta de Tabela:**

```mermaid
sequenceDiagram
    participant Cliente as Cliente SNMP
    participant SNMPD as snmpd daemon
    participant Agent as process_table_agent.sh
    participant PS as comando ps
    
    Note over Cliente: Listar toda a tabela
    Cliente->>SNMPD: snmpwalk processTable
    
    loop Para cada coluna e PID
        SNMPD->>Agent: getnext OID_anterior
        Agent->>PS: ps aux --sort=-pcpu
        PS-->>Agent: lista de processos
        Agent->>Agent: parsear linha<br/>extrair PID, nome, CPU, MEM
        Agent-->>SNMPD: proximo OID + valor
        SNMPD-->>Cliente: processName.1234 = apache2
    end
    
    Note over Cliente: Tabela completa recebida
```

**Arquitetura do Cenário:**

```mermaid
graph TB
    subgraph "Cliente SNMP"
        WALK["snmpwalk<br/>snmptable"]
    end
    
    subgraph "Servidor SNMP"
        SNMPD2["snmpd daemon"]
        CONFIG2["pass_persist config"]
    end
    
    subgraph "Agente de Tabela"
        AGENT2["process_table_agent.sh"]
        CACHE["Cache de processos<br/>atualizado periodicamente"]
    end
    
    subgraph "Sistema Operacional"
        PS["ps aux<br/>informacoes de processos"]
        PROC["proc filesystem"]
    end
    
    WALK -->|snmpwalk OID tabela| SNMPD2
    SNMPD2 -.->|carrega| CONFIG2
    SNMPD2 <-->|getnext iterativo| AGENT2
    AGENT2 -->|executa| PS
    PS -->|lê| PROC
    AGENT2 -.->|mantém| CACHE
    
    style WALK fill:#a8dadc
    style SNMPD2 fill:#95e1d3
    style AGENT2 fill:#ffe66d
    style PS fill:#4ecdc4
```

---

### Tarefa 03: SNMP Traps para Monitoramento

**Objetivo:** Implementar sistema de notificações assíncronas (traps) para alertar sobre condições críticas de temperatura e uso de disco.

**Conceitos Demonstrados:**
- SNMP Notifications (Traps)
- Varbinds (variáveis enviadas no trap)
- snmptrapd (receptor de traps)
- Handlers para processamento automático
- Níveis de severidade

**Objetos da MIB (CUSTOM-TRAPS-MIB):**

**Traps:**

| OID | Nome | Descrição |
|-----|------|-----------|
| .1.3.6.1.4.1.99999.0.1 | myHighTemperatureTrap | Enviado quando temperatura excede limite |
| .1.3.6.1.4.1.99999.0.2 | myDiskFullTrap | Enviado quando disco atinge capacidade crítica |

**Objetos (Varbinds):**

| OID | Nome | Tipo | Descrição |
|-----|------|------|-----------|
| .1.3.6.1.4.1.99999.3.1.1.0 | currentTemperature | INTEGER | Temperatura atual (°C) |
| .1.3.6.1.4.1.99999.3.1.2.0 | temperatureThreshold | INTEGER | Limite de temperatura (°C) |
| .1.3.6.1.4.1.99999.3.1.3.0 | diskPartition | OCTET STRING | Nome da partição (/dev/sda1) |
| .1.3.6.1.4.1.99999.3.1.4.0 | diskUsagePercent | INTEGER | Percentual de uso (0-100) |
| .1.3.6.1.4.1.99999.3.1.5.0 | diskTotalMB | INTEGER | Espaço total (MB) |
| .1.3.6.1.4.1.99999.3.1.6.0 | diskUsedMB | INTEGER | Espaço usado (MB) |
| .1.3.6.1.4.1.99999.3.1.7.0 | alertTimestamp | OCTET STRING | Data/hora do alerta |
| .1.3.6.1.4.1.99999.3.1.8.0 | alertSeverity | INTEGER | Severidade: 1=warning, 2=critical, 3=emergency |

**Fluxo de Trap:**

```mermaid
sequenceDiagram
    participant Monitor as temperature_monitor.sh
    participant System as Sensor de Temperatura
    participant SNMP as snmptrap
    participant Receiver as snmptrapd porta 162
    participant Handler as handle_temperature_trap.sh
    participant Log as temperature_traps.log
    
    loop A cada intervalo
        Monitor->>System: Ler temperatura
        System-->>Monitor: 92 graus C
        
        alt Temperatura maior que limite
            Note over Monitor: 92C maior que 70C<br/>Severidade: Emergency
            
            Monitor->>SNMP: Preparar trap com varbinds
            Note over SNMP: Trap: .1.3.6.1.4.1.99999.0.1<br/>currentTemperature=92<br/>threshold=70<br/>severity=3
            
            SNMP->>Receiver: SNMPv2c TRAP UDP
            
            alt Processamento Automático
                Receiver->>Handler: Executar traphandle
                Handler->>Handler: Parsear varbinds
                Handler->>Log: Registrar alerta
                Note over Log: EMERGENCY: 92C<br/>ACTION: Immediate attention
                
                opt Severidade 3
                    Handler->>Handler: Enviar email/SMS
                end
            end
            
            Receiver->>Receiver: Log syslog
        end
    end
```

**Arquitetura do Cenário:**

```mermaid
graph TB
    subgraph "Sistema Monitorado"
        TEMP["Sensor CPU<br/>lm-sensors"]
        DISK["Sistema de Arquivos<br/>df command"]
    end
    
    subgraph "Scripts de Monitoramento"
        TEMPMON["temperature_monitor.sh<br/>threshold: 70C"]
        DISKMON["disk_monitor.sh<br/>threshold: 90 percent"]
    end
    
    subgraph "Protocolo SNMP"
        TRAP1["myHighTemperatureTrap<br/>.1.3.6.1.4.1.99999.0.1"]
        TRAP2["myDiskFullTrap<br/>.1.3.6.1.4.1.99999.0.2"]
        MIB["CUSTOM-TRAPS-MIB.txt"]
    end
    
    subgraph "Receptor - porta 162"
        TRAPD["snmptrapd daemon"]
        CONF["snmptrapd.conf<br/>traphandle config"]
    end
    
    subgraph "Processamento"
        H1["handle_temperature_trap.sh"]
        H2["handle_disk_trap.sh"]
        L1["temperature_traps.log"]
        L2["disk_traps.log"]
    end
    
    TEMP -->|leitura| TEMPMON
    DISK -->|df -h| DISKMON
    
    TEMPMON -->|condicao critica| TRAP1
    DISKMON -->|condicao critica| TRAP2
    
    TRAP1 -.->|definido em| MIB
    TRAP2 -.->|definido em| MIB
    
    TRAP1 -->|SNMPv2c UDP| TRAPD
    TRAP2 -->|SNMPv2c UDP| TRAPD
    
    TRAPD -.->|carrega| CONF
    TRAPD -->|executa| H1
    TRAPD -->|executa| H2
    
    H1 -->|escreve| L1
    H2 -->|escreve| L2
    
    style TEMP fill:#ff6b6b
    style DISK fill:#ff6b6b
    style TRAP1 fill:#ffe66d
    style TRAP2 fill:#ffe66d
    style TRAPD fill:#95e1d3
    style H1 fill:#4ecdc4
    style H2 fill:#4ecdc4
```

## Estrutura do Projeto

```
HandsOn/
├── README.md                           # Este arquivo
│
├── Tarefa01_MIB_Control/               # Controle de serviço snmpd
│   ├── CUSTOM-CONTROL-MIB.txt          # Definição da MIB
│   ├── snmpd_control_agent.sh          # Agente SNMP em bash
│   └── README.md                       # Documentação detalhada
│
├── Tarefa02_Tabela_Processos/          # Tabela de processos
│   ├── PROCESS-TABLE-MIB.txt           # Definição da MIB
│   ├── process_table_agent.sh          # Agente de tabela
│   └── README.md                       # Documentação detalhada
│
└── Tarefa03_Traps/                     # Sistema de alertas
    ├── CUSTOM-TRAPS-MIB.txt            # Definição da MIB
    ├── temperature_monitor.sh          # Monitor de temperatura
    ├── disk_monitor.sh                 # Monitor de disco
    └── README.md                       # Documentação detalhada
```

## Pré-requisitos

### Software Necessário

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

### Conhecimentos Recomendados

- Conceitos básicos de SNMP (MIB, OID, Community, Agents)
- Bash scripting
- Comandos Linux básicos

## Guia Rápido de Instalação

### 1. Clonar o repositório

```bash
git clone git@github.com:mdo-br/Gerencia_Redes.git
cd Gerencia_Redes/HandsOn
```

### 2. Copiar as MIBs

**Linux:**
```bash
# Sistema (requer sudo)
sudo cp Tarefa01_MIB_Control/CUSTOM-CONTROL-MIB.txt /usr/share/snmp/mibs/
sudo cp Tarefa02_Tabela_Processos/PROCESS-TABLE-MIB.txt /usr/share/snmp/mibs/
sudo cp Tarefa03_Traps/CUSTOM-TRAPS-MIB.txt /usr/share/snmp/mibs/

# Ou usuário local (sem sudo)
mkdir -p ~/.snmp/mibs
cp Tarefa01_MIB_Control/CUSTOM-CONTROL-MIB.txt ~/.snmp/mibs/
cp Tarefa02_Tabela_Processos/PROCESS-TABLE-MIB.txt ~/.snmp/mibs/
cp Tarefa03_Traps/CUSTOM-TRAPS-MIB.txt ~/.snmp/mibs/
```

**MacOS:**
```bash
mkdir -p ~/.snmp/mibs
cp Tarefa01_MIB_Control/CUSTOM-CONTROL-MIB.txt ~/.snmp/mibs/
cp Tarefa02_Tabela_Processos/PROCESS-TABLE-MIB.txt ~/.snmp/mibs/
cp Tarefa03_Traps/CUSTOM-TRAPS-MIB.txt ~/.snmp/mibs/
```

### 3. Verificar instalação das MIBs

```bash
snmptranslate -m +CUSTOM-CONTROL-MIB -On CUSTOM-CONTROL-MIB::snmpdStatus
snmptranslate -m +PROCESS-TABLE-MIB -On PROCESS-TABLE-MIB::processTable
snmptranslate -m +CUSTOM-TRAPS-MIB -On CUSTOM-TRAPS-MIB::myHighTemperatureTrap
```

Se funcionar, você verá os OIDs numéricos correspondentes.

## Testes Rápidos

### Tarefa 01: Controlar snmpd

```bash
cd Tarefa01_MIB_Control

# Configurar agente
sudo cp snmpd_control_agent.sh /usr/local/bin/
echo 'pass_persist .1.3.6.1.4.1.99999.1 /usr/local/bin/snmpd_control_agent.sh' | sudo tee -a /etc/snmp/snmpd.conf

# Reiniciar snmpd
sudo systemctl restart snmpd

# Testar
snmpget -v2c -c public localhost .1.3.6.1.4.1.99999.1.1.0  # Ver status
snmpset -v2c -c private localhost .1.3.6.1.4.1.99999.1.2.0 i 2  # Parar serviço
```

### Tarefa 02: Visualizar Processos

```bash
cd Tarefa02_Tabela_Processos

# Configurar agente
sudo cp process_table_agent.sh /usr/local/bin/
echo 'pass_persist .1.3.6.1.4.1.99999.2 /usr/local/bin/process_table_agent.sh' | sudo tee -a /etc/snmp/snmpd.conf

# Reiniciar snmpd
sudo systemctl restart snmpd

# Listar processos
snmpwalk -v2c -c public localhost .1.3.6.1.4.1.99999.2
```

### Tarefa 03: Receber Alertas

```bash
cd Tarefa03_Traps

# Terminal 1: Iniciar receptor de traps
sudo snmptrapd -f -Lo

# Terminal 2: Executar monitor (em outra aba)
./temperature_monitor.sh 50 localhost  # Limite baixo para forçar alerta
# ou
./disk_monitor.sh 50 localhost
```

## Documentação Detalhada

### Material de Estudo
[MATERIAL_ESTUDO.md](MATERIAL_ESTUDO.md) - Guia com:
- RFCs recomendadas (seções específicas)
- Tutoriais e vídeos
- Livros e cursos
- Plano de estudo sugerido (2 semanas)
- Checklist de conhecimento

### Documentação por Tarefa
Cada tarefa possui documentação completa em seu respectivo diretório:

- [Tarefa 01 - MIB Control](Tarefa01_MIB_Control/README.md)
- [Tarefa 02 - Tabela de Processos](Tarefa02_Tabela_Processos/README.md)
- [Tarefa 03 - SNMP Traps](Tarefa03_Traps/README.md)

## Conceitos SNMP Demonstrados

### 1. MIB (Management Information Base)
- Estrutura de dados hierárquica
- Sintaxe SMIv2 (Structure of Management Information)
- Enterprise OID customizado (.1.3.6.1.4.1.99999)

### 2. Tipos de Objetos
- **Escalares**: Objetos simples (status, controle)
- **Tabelas**: Estruturas indexadas (processos)
- **Notificações**: Traps para eventos assíncronos

### 3. Operações SNMP
- **GET**: Leitura de objetos (.0 para escalares)
- **GETNEXT**: Travessia de árvore MIB
- **SET**: Escrita de valores
- **TRAP**: Envio de notificações

### 4. Mecanismo pass_persist
- Agentes externos ao snmpd
- Protocolo stdin/stdout
- Persistência de estado

### 5. Community Strings
- **public**: Leitura (default)
- **private**: Escrita (default)

## Troubleshooting Comum

### MIB não encontrada
```bash
# Verificar localização
ls -l ~/.snmp/mibs/
ls -l /usr/share/snmp/mibs/

# Forçar carregamento
export MIBS=+CUSTOM-CONTROL-MIB:+PROCESS-TABLE-MIB:+CUSTOM-TRAPS-MIB
```

### Timeout ao consultar
```bash
# Verificar se snmpd está rodando
sudo systemctl status snmpd

# Ver logs
sudo tail -f /var/log/syslog | grep snmp

# Testar localmente
snmpwalk -v2c -c public localhost system
```

### Permissões negadas
```bash
# Scripts precisam ser executáveis
chmod +x Tarefa01_MIB_Control/snmpd_control_agent.sh
chmod +x Tarefa02_Tabela_Processos/process_table_agent.sh
chmod +x Tarefa03_Traps/*.sh

# Agentes precisam ser copiados para local acessível
sudo cp Tarefa*/*.sh /usr/local/bin/
```

### Agent não responde
```bash
# Testar agente diretamente
echo -e "PING\nget\n.1.3.6.1.4.1.99999.1.1.0" | /usr/local/bin/snmpd_control_agent.sh

# Verificar configuração no snmpd.conf
grep pass_persist /etc/snmp/snmpd.conf

# Reiniciar snmpd após alterações
sudo systemctl restart snmpd
```

## Diagramas de Arquitetura

### Estrutura OID Customizada (Árvore MIB Completa)

```mermaid
graph TD
    ROOT[.1.3.6.1.4.1.99999<br/>enterprises.99999]
    
    ROOT --> T1[.1<br/>customControlMIB<br/>TAREFA 01]
    ROOT --> T2[.2<br/>processTableMIB<br/>TAREFA 02]
    ROOT --> T3[.3<br/>customTrapsMIB<br/>TAREFA 03]
    
    T1 --> T1O1[.1.0<br/>snmpdStatus<br/>READ-ONLY<br/>INTEGER 1-3]
    T1 --> T1O2[.2.0<br/>snmpdControl<br/>READ-WRITE<br/>INTEGER 1-4]
    
    T2 --> T2T[.1<br/>processTable]
    T2T --> T2E[.1<br/>processEntry]
    T2E --> T2C1[.1.PID processPID]
    T2E --> T2C2[.2.PID processName]
    T2E --> T2C3[.3.PID processCPU]
    T2E --> T2C4[.4.PID processMemory]
    T2E --> T2C5[.5.PID processUptime]
    
    T3 --> T3N[.0<br/>notifications]
    T3 --> T3O[.1<br/>objects]
    
    T3N --> T3N1[.1<br/>myHighTemperatureTrap]
    T3N --> T3N2[.2<br/>myDiskFullTrap]
    
    T3O --> T3O1[.1.0 currentTemperature]
    T3O --> T3O2[.2.0 temperatureThreshold]
    T3O --> T3O3[.3.0 diskPartition]
    T3O --> T3O4[.4.0 diskUsagePercent]
    T3O --> T3O5[.5.0 diskTotalMB]
    T3O --> T3O6[.6.0 diskUsedMB]
    T3O --> T3O7[.7.0 alertTimestamp]
    T3O --> T3O8[.8.0 alertSeverity]
    
    style ROOT fill:#a8dadc
    style T1 fill:#95e1d3
    style T2 fill:#ffe66d
    style T3 fill:#ff6b6b
    style T1O1 fill:#d4f1f4
    style T1O2 fill:#d4f1f4
    style T2C1 fill:#fff9c4
    style T2C2 fill:#fff9c4
    style T2C3 fill:#fff9c4
    style T2C4 fill:#fff9c4
    style T2C5 fill:#fff9c4
    style T3N1 fill:#ffcccb
    style T3N2 fill:#ffcccb
```

### Comparação dos Três Mecanismos SNMP

```mermaid
graph LR
    subgraph "TAREFA 01: GET/SET - Objetos Escalares"
        C1[Cliente SNMP]
        S1[snmpd<br/>porta 161]
        A1[Agent]
        C1 -->|GET/SET<br/>Request| S1
        S1 <-->|pipe| A1
        S1 -->|Response| C1
        style S1 fill:#95e1d3
    end
    
    subgraph "TAREFA 02: GETNEXT - Tabelas"
        C2[Cliente SNMP]
        S2[snmpd<br/>porta 161]
        A2[Agent]
        C2 -->|GETNEXT<br/>iterativo| S2
        S2 <-->|pipe| A2
        S2 -->|Response<br/>multiplas linhas| C2
        style S2 fill:#ffe66d
    end
    
    subgraph "TAREFA 03: TRAP - Notificações"
        M3[Monitor Script]
        T3[snmptrap]
        R3[snmptrapd<br/>porta 162]
        H3[Handler]
        M3 -->|evento critico| T3
        T3 -->|TRAP<br/>assincrono| R3
        R3 -->|executa| H3
        style R3 fill:#ff6b6b
    end
```

### Integração Completa do Sistema

```mermaid
graph TB
    subgraph "Gerente SNMP - Estação de Monitoramento"
        NMS[Network Management System<br/>Software de Gerência]
        SNMPCLI[Comandos SNMP<br/>snmpget, snmpset, snmpwalk]
        TRAPRCV[Receptor de Traps<br/>snmptrapd]
    end
    
    subgraph "Agente SNMP - Servidor Monitorado"
        SNMPD["snmpd daemon<br/>Master Agent<br/>porta 161 UDP"]
        
        subgraph "Agentes Externos"
            AG1["snmpd_control_agent.sh<br/>Tarefa 01"]
            AG2["process_table_agent.sh<br/>Tarefa 02"]
        end
        
        subgraph "Monitores"
            MON1["temperature_monitor.sh<br/>Tarefa 03"]
            MON2["disk_monitor.sh<br/>Tarefa 03"]
        end
    end
    
    subgraph "Recursos do Sistema"
        SYS["systemctl"]
        PROC["proc filesystem"]
        SENSORS["lm-sensors"]
        FS["Filesystem"]
    end
    
    NMS -->|GET/SET| SNMPD
    SNMPCLI -->|GET/SET/GETNEXT| SNMPD
    
    SNMPD <-->|pass_persist| AG1
    SNMPD <-->|pass_persist| AG2
    
    AG1 -->|controla| SYS
    AG2 -->|lê| PROC
    
    MON1 -->|lê| SENSORS
    MON2 -->|lê| FS
    
    MON1 -->|snmptrap| TRAPRCV
    MON2 -->|snmptrap| TRAPRCV
    
    style NMS fill:#a8dadc
    style SNMPD fill:#95e1d3
    style AG1 fill:#ffe66d
    style AG2 fill:#ffe66d
    style MON1 fill:#ff6b6b
    style MON2 fill:#ff6b6b
    style TRAPRCV fill:#ffcccb
```

## Plataformas Testadas

- ✅ Ubuntu 20.04/22.04
- ✅ Debian 11/12
- ✅ CentOS 7/8
- ✅ MacOS 13+ (Ventura/Sonoma)
- ⚠️ Windows (via WSL2)

## Recursos Adicionais

### Comandos SNMP Úteis

```bash
# Listar toda a árvore MIB customizada
snmpwalk -v2c -c public localhost .1.3.6.1.4.1.99999

# Ver em formato legível (com nomes)
snmpwalk -v2c -c public -m +ALL localhost .1.3.6.1.4.1.99999

# Traduzir OID numérico para nome
snmptranslate -m +CUSTOM-CONTROL-MIB .1.3.6.1.4.1.99999.1.1.0

# Traduzir nome para OID
snmptranslate -m +CUSTOM-CONTROL-MIB -On CUSTOM-CONTROL-MIB::snmpdStatus.0

# Ver descrição de um objeto
snmptranslate -m +CUSTOM-CONTROL-MIB -Td CUSTOM-CONTROL-MIB::snmpdControl

# Validar sintaxe de MIB
smilint -l 3 CUSTOM-CONTROL-MIB.txt
```

### RFCs Relacionadas

- **RFC 1155** - SMI (Structure of Management Information)
- **RFC 2578** - SMIv2 (Structure of Management Information Version 2)
- **RFC 3411-3418** - SNMP Version 3
- **RFC 3416** - Protocol Operations (includes TRAP)
- **RFC 4181** - Guidelines for MIB Authors

### Links Úteis

- [Net-SNMP Official Site](http://www.net-snmp.org/)
- [Net-SNMP Tutorial](http://www.net-snmp.org/tutorial/tutorial-5/)
- [MIB Smithy](https://www.mibsmitty.com/) - Ferramenta de validação de MIBs
- [OID Repository](http://www.oid-info.com/)

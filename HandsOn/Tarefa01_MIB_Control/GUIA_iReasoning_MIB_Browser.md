# Guia Completo: iReasoning MIB Browser com CUSTOM-CONTROL-MIB

## Índice
1. [Instalação do iReasoning](#instalação)
2. [Configuração Obrigatória](#configuração-crítica)
3. [Carregando a MIB](#carregar-mib)
4. [Testes Passo a Passo](#testes)
5. [Troubleshooting](#problemas-comuns)

---

## INSTALAÇÃO DO iReasoning MIB Browser

### Download e Extração

```bash
# Navegar para Downloads
cd ~/Downloads

# Baixar (se ainda não tiver)
# URL: https://www.ireasoning.com/mibbrowser.shtml
# Arquivo: mibbrowser_linux_x64.zip

# Extrair
unzip mibbrowser_linux_x64.zip

# Estrutura criada:
# ~/Downloads/ireasoning/mibbrowser/
```

### Copiar MIB Customizada

```bash
# Copiar CUSTOM-CONTROL-MIB para diretório do iReasoning
cp ~/Projetos/Gerencia_de_Redes/HandsOn/Tarefa01_MIB_Control/CUSTOM-CONTROL-MIB.txt \
   ~/Downloads/ireasoning/mibbrowser/mibs/

# Verificar
ls -l ~/Downloads/ireasoning/mibbrowser/mibs/CUSTOM-CONTROL-MIB.txt
```

### Iniciar o Browser

```bash
cd ~/Downloads/ireasoning/mibbrowser
./browser.sh
```

**Nota**: Warnings sobre "illegal reflective access" são normais e não afetam o funcionamento.

---

## CONFIGURAÇÃO CRÍTICA (OBRIGATÓRIA!)

### Campos na Interface Principal

Na parte superior da janela do iReasoning, **TODOS** os campos abaixo são obrigatórios:

```
┌──────────────────────────────────────────────────────────┐
│ Address: localhost          ⬅️ Ou 127.0.0.1            │
│ Port: 161                   ⬅️ Porta padrão SNMP       │
│ Version: SNMPv2c            ⬅️ IMPORTANTE! Não usar v1 │
│ Read Community:  public     ⬅️ Para GET/WALK           │
│ Write Community: private    ⬅️ CRÍTICO PARA SET!       │
│ Timeout: 5000               ⬅️ Milissegundos           │
│ Retries: 3                  ⬅️ Tentativas             │
└──────────────────────────────────────────────────────────┘
```

### ⚠️ ERROS COMUNS DE CONFIGURAÇÃO

| Problema | Causa | Sintoma |
|----------|-------|---------|
| SET falha | Write Community vazia | "No Such Name" ou "notWritable" |
| SET falha | Version = v1 | "No Such Name" |
| Timeout | Address errado | "Timeout waiting for response" |

### Como Configurar Corretamente

1. **No menu superior**, localize os campos de configuração
2. **Preencha TODOS os campos** conforme tabela acima
3. **Clique em "Connect"** ou tecle Enter
4. **Teste GET** antes de tentar SET

---

## 📖 CARREGANDO A MIB CUSTOMIZADA

1. **Menu**: `File` → `Load MIB File...`
2. **Navegar até**: `~/Downloads/ireasoning/mibbrowser/mibs/CUSTOM-CONTROL-MIB.txt`
3. **Clicar**: `Open`
4. **Aguardar**: A MIB será compilada e carregada na árvore

### 2. Configurar Conexão SNMP

Na parte superior da janela:

- **Address**: `localhost` ou `127.0.0.1`
- **Port**: `161` (padrão SNMP)
- **Version**: `SNMPv2c`
- **Read Community**: `public`
- **Write Community**: `private`
- **Timeout**: `5000` ms
- **Retries**: `3`

### 3. Navegar até a MIB Customizada

Na árvore à esquerda, expandir:

```
.iso (1)
  └─ .org (3)
      └─ .dod (6)
          └─ .internet (1)
              └─ .private (4)
                  └─ .enterprises (1)
                      └─ .99999
                          └─ .customControlModule (1)
                              └─ .snmpdObjects (1)
                                  ├─ .snmpdStatus (1) .0
                                  ├─ .snmpdControl (2) .0
                                  ├─ .snmpdUptime (3) .0
                                  └─ .snmpdVersion (4) .0
```

**OID Base**: `.1.3.6.1.4.1.99999.1.1`

### 4. Testar Operação GET

1. **Clicar** no objeto desejado (ex: `snmpdStatus`)
2. **Botão direito** → `Operations` → `Get`
3. **OU** clicar no botão `Get` na toolbar
4. **Resultado** aparecerá no painel inferior:
   ```
   .1.3.6.1.4.1.99999.1.1.1.0 = INTEGER: 1
   ```

### 5. Testar Operação WALK

1. **Clicar** no nó pai: `snmpdObjects` (`.1.3.6.1.4.1.99999.1.1`)
2. **Botão direito** → `Operations` → `Walk`
3. **OU** clicar no botão `Walk` na toolbar
4. **Resultado**: Lista com todos os 4 objetos:
   ```
   .1.3.6.1.4.1.99999.1.1.1.0 = INTEGER: 1
   .1.3.6.1.4.1.99999.1.1.2.0 = INTEGER: 0
   .1.3.6.1.4.1.99999.1.1.3.0 = STRING: "Sat 2026-01-17 10:11:05 -03"
   .1.3.6.1.4.1.99999.1.1.4.0 = STRING: ""
   ```

### 6. Testar Operação SET (Controle do Serviço)

#### 6.1 Verificar Uptime ANTES
1. **Clicar** em `snmpdUptime` (`.1.3.6.1.4.1.99999.1.1.3.0`)
2. **Fazer GET** e anotar o valor

#### 6.2 Executar RESTART
1. **Clicar** em `snmpdControl` (`.1.3.6.1.4.1.99999.1.1.2.0`)
2. **Botão direito** → `Operations` → `Set`
3. **Janela SET**:
   - **OID**: `.1.3.6.1.4.1.99999.1.1.2.0` (já preenchido)
   - **Type**: `INTEGER`
   - **Value**: `2` (restart)
4. **Clicar**: `OK`
5. **Aguardar**: 5-10 segundos

#### 6.3 Verificar Uptime DEPOIS
1. **Clicar** em `snmpdUptime` novamente
2. **Fazer GET**
3. **Validar**: O uptime deve ter mudado (nova data/hora)

### 7. Valores do snmpdControl

| Valor | Ação | Descrição |
|-------|------|-----------|
| 0 | noop | Nenhuma operação |
| 1 | stop | Para o serviço snmpd |
| 2 | restart | Reinicia o serviço snmpd |
| 3 | start | Inicia o serviço snmpd |

## Capturas de Tela Recomendadas

Para documentação do HandsOn, capturar:

1. **Árvore MIB** mostrando `.1.3.6.1.4.1.99999` expandido
2. **Resultado GET** de todos os 4 objetos
3. **Resultado WALK** completo
4. **Operação SET** (antes/durante/depois do restart)
5. **Mudança do uptime** comprovando restart

## 📊 Atalhos Úteis

- **F5**: Atualizar árvore MIB
- **Ctrl+G**: Get
- **Ctrl+W**: Walk
- **Ctrl+S**: Set
- **Ctrl+L**: Load MIB

## Troubleshooting

### Erro: "Timeout waiting for response"
- Verificar se snmpd está rodando: `systemctl status snmpd`
- Verificar firewall: `sudo ufw status`

### Erro: "No response from agent"
- Verificar community string (public/private)
- Verificar se OID está na view: `sudo grep "view.*99999" /etc/snmp/snmpd.conf`

### Erro: "notWritable" no SET
- Verificar rwcommunity: Deve usar community `private`
- Verificar view na rwcommunity: `-V systemonly`

### MIB não aparece na árvore
- Recarregar: `File` → `Reload All MIBs`
- Verificar compilação: `Tools` → `MIB Compiler`

## 🔗 Comparação com CLI

### iReasoning vs snmpget
```bash
# CLI
snmpget -v2c -c public localhost .1.3.6.1.4.1.99999.1.1.1.0

# iReasoning
# Clicar em snmpdStatus → Get
```

### iReasoning vs snmpwalk
```bash
# CLI
snmpwalk -v2c -c public localhost .1.3.6.1.4.1.99999.1

# iReasoning
# Clicar em snmpdObjects → Walk
```

### iReasoning vs snmpset
```bash
# CLI
snmpset -v2c -c private localhost .1.3.6.1.4.1.99999.1.1.2.0 i 2

# iReasoning
# Clicar em snmpdControl → Set → Value: 2
```

## Vantagens do iReasoning

✅ **Interface Gráfica**: Visualização hierárquica da MIB  
✅ **Navegação Fácil**: Clicar para selecionar OIDs  
✅ **Auto-completar**: Não precisa memorizar OIDs  
✅ **Múltiplas Operações**: Get, Walk, Set, GetNext, GetBulk  
✅ **Histórico**: Mantém log das operações  
✅ **Export**: Salvar resultados em arquivo  

## 🎓 Para o Relatório

Incluir no documento final:

1. Screenshot da árvore MIB carregada
2. Screenshot do resultado GET de todos objetos
3. Screenshot do resultado WALK
4. Sequência de capturas do SET (antes/depois uptime)
5. Log de operações do painel inferior

---

**Autor**: Marcos Dantas Ortiz  
**Data**: 17/01/2026  
**Disciplina**: Gerência de Redes - MDCC/UFC

# INSTALAÇÃO RÁPIDA - Tarefa 01: CUSTOM-CONTROL-MIB

**Sistema:** Ubuntu 20.04+ / Debian  
**Pré-requisitos:** Acesso sudo

---

## ⚡ COMANDOS DE INSTALAÇÃO (COPIAR E COLAR)

### 1. Instalar Net-SNMP
```bash
sudo apt-get update && sudo apt-get install -y snmpd snmp libsnmp-dev
```

### 2. Navegar para o diretório do projeto
```bash
cd ~/Projetos/Gerencia_de_Redes/HandsOn/Tarefa01_MIB_Control
```

### 3. Instalar MIB
```bash
sudo cp CUSTOM-CONTROL-MIB.txt /usr/share/snmp/mibs/
```

### 4. Instalar Agente
```bash
sudo cp snmpd_control_agent.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/snmpd_control_agent.sh
```

### 5. Configurar Sudoers
```bash
sudo bash -c 'cat > /etc/sudoers.d/snmpd-control << EOF
Debian-snmp ALL=(ALL) NOPASSWD: /bin/systemctl start snmpd, /bin/systemctl stop snmpd, /bin/systemctl restart snmpd
EOF'

sudo chmod 0440 /etc/sudoers.d/snmpd-control
sudo visudo -c
```

### 6. Fazer Backup e Configurar snmpd.conf
```bash
# Backup
sudo cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.backup

# Adicionar configuração
sudo bash -c 'cat >> /etc/snmp/snmpd.conf << EOF

# ==================================================================
# CUSTOM-CONTROL-MIB Configuration
# ==================================================================
view   systemonly  included   .1.3.6.1.4.1.99999
rocommunity public localhost -V systemonly
rwcommunity private localhost -V systemonly
pass .1.3.6.1.4.1.99999.1 /usr/local/bin/snmpd_control_agent.sh
# ==================================================================
EOF'
```

### 7. Reiniciar snmpd
```bash
sudo systemctl restart snmpd
sudo systemctl status snmpd
```

---

## VALIDAÇÃO RÁPIDA

### Teste GET:
```bash
snmpget -v2c -c public localhost .1.3.6.1.4.1.99999.1.1.1.0
```
**Esperado:** `INTEGER: 1`

### Teste WALK:
```bash
snmpwalk -v2c -c public localhost .1.3.6.1.4.1.99999.1
```
**Esperado:** 4 OIDs listados

### Teste SET (Restart):
```bash
# Antes
snmpget -v2c -c public localhost .1.3.6.1.4.1.99999.1.1.3.0

# SET
snmpset -v2c -c private localhost .1.3.6.1.4.1.99999.1.1.2.0 i 2

# Aguardar 5 segundos
sleep 5

# Depois (uptime deve ter mudado)
snmpget -v2c -c public localhost .1.3.6.1.4.1.99999.1.1.3.0
```

---

## PROBLEMAS COMUNS

### ❌ "Timeout: No Response"
```bash
sudo systemctl status snmpd  # Verificar se está rodando
sudo systemctl start snmpd   # Se não estiver
```

### ❌ "No Such Object"
```bash
# Verificar se OID está na view
sudo grep "view.*99999" /etc/snmp/snmpd.conf
# Se não aparecer nada, repetir passo 6
```

### ❌ "notWritable" no SET
```bash
# Verificar rwcommunity
sudo grep "rwcommunity" /etc/snmp/snmpd.conf
# Deve ter: rwcommunity private localhost -V systemonly
```

### ❌ SET não reinicia serviço
```bash
# Testar sudoers
sudo -u Debian-snmp sudo systemctl status snmpd
# Não deve pedir senha. Se pedir, repetir passo 5
```

---

## 📱 iReasoning MIB Browser (OPCIONAL)

### Instalação:
```bash
cd ~/Downloads
# Baixar mibbrowser_linux_x64.zip de:
# https://www.ireasoning.com/mibbrowser.shtml

unzip mibbrowser_linux_x64.zip
cp CUSTOM-CONTROL-MIB.txt ~/Downloads/ireasoning/mibbrowser/mibs/
cd ~/Downloads/ireasoning/mibbrowser
./browser.sh
```

### ⚠️ CONFIGURAÇÃO OBRIGATÓRIA:
```
Address: localhost
Port: 161
Version: SNMPv2c         ⬅️ IMPORTANTE!
Read Community: public
Write Community: private  ⬅️ OBRIGATÓRIO!
```

**Sem Write Community preenchida, SET não funciona!**

---

## 📋 CHECKLIST

- [ ] Net-SNMP instalado
- [ ] MIB copiada
- [ ] Agente instalado com permissão +x
- [ ] Sudoers configurado (modo 0440)
- [ ] snmpd.conf modificado (view, communities, pass)
- [ ] snmpd reiniciado e ativo
- [ ] GET funciona
- [ ] WALK funciona  
- [ ] SET funciona (uptime muda)

---

## 📚 DOCUMENTAÇÃO COMPLETA

Ver `README.md` para:
- Explicação detalhada de cada passo
- Troubleshooting completo
- Arquitetura técnica
- Referências e teoria

---

**Autores:** ANTONIA MAYARA, JOÃO BATISTA, Marcos Dantas  
**MDCC/UFC - Gerência de Redes - Janeiro 2026**

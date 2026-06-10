# Network and Port Requirements

## Production Server (192.168.144.7)

### Required Open Ports
- **Port 3724/tcp**: Authserver (WoW client authentication)
- **Port 8585/tcp**: Worldserver (game world connections)
- **Port 7878/tcp**: SOAP (server management API)
- **Port 3306/tcp**: MySQL (for testing server read-only access)
  - Only needs to accept connections from testing server IP: 192.168.144.8

### Docker Port Mappings
```
ac-authserver: 0.0.0.0:3724->3724/tcp
ac-worldserver: 0.0.0.0:8585->8585/tcp, 0.0.0.0:7878->7878/tcp
ac-database: 0.0.0.0:3306->3306/tcp
```

## Testing Server (192.168.144.8)

### Required Open Ports
- **Port 8085/tcp**: Worldserver (game world connections)
- **Port 7878/tcp**: SOAP (server management API)

### Docker Port Mappings
```
testing-ac-worldserver: 0.0.0.0:8085->8585/tcp, 0.0.0.0:7878->7878/tcp
testing-ac-database: 127.0.0.1:3306->3306/tcp (localhost only)
```

## Port Mapping Technical Details

### Worldserver Internal Port
Worldserver configuration files hardcode the internal listening port as **8585**. This is configured in `worldserver.conf`:
```
WorldServerPort = 8585
```

Therefore, Docker port mappings must always map the external port to internal port 8585:
- Production: `8585:8585` (external 8585 → internal 8585)
- Testing: `8085:8585` (external 8085 → internal 8585)

### Docker Compose Port Conflict Workaround
The base `docker-compose.yml` and `docker-compose.override.yml` files both define port mappings. Docker Compose **merges** these arrays, which can cause port conflicts.

To prevent the base file from binding the public worldserver port, set in `.env`:
```bash
DOCKER_WORLD_EXTERNAL_PORT=127.0.0.1:9999
```

This makes the base file bind to localhost only on a dummy port (9999), while the override file binds the correct public port.

## Firewall Configuration

### Check Current Firewall Status
```bash
# Check if ufw is running
systemctl status ufw

# Check if firewalld is running
systemctl status firewalld

# Check iptables rules
iptables -L -n -v
```

### Opening Ports with ufw (Ubuntu/Debian)
```bash
# Production server
ufw allow 3724/tcp comment 'AzerothCore authserver'
ufw allow 8585/tcp comment 'AzerothCore worldserver'
ufw allow 7878/tcp comment 'AzerothCore SOAP'
ufw allow from 192.168.144.8 to any port 3306 proto tcp comment 'MySQL for testing server'
ufw reload

# Testing server
ufw allow 8085/tcp comment 'AzerothCore testing worldserver'
ufw allow 7878/tcp comment 'AzerothCore testing SOAP'
ufw reload
```

### Opening Ports with firewalld (RHEL/CentOS)
```bash
# Production server
firewall-cmd --permanent --add-port=3724/tcp
firewall-cmd --permanent --add-port=8585/tcp
firewall-cmd --permanent --add-port=7878/tcp
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.144.8" port port="3306" protocol="tcp" accept'
firewall-cmd --reload

# Testing server
firewall-cmd --permanent --add-port=8085/tcp
firewall-cmd --permanent --add-port=7878/tcp
firewall-cmd --reload
```

### Opening Ports with iptables
```bash
# Production server
iptables -I INPUT -p tcp --dport 3724 -j ACCEPT
iptables -I INPUT -p tcp --dport 8585 -j ACCEPT
iptables -I INPUT -p tcp --dport 7878 -j ACCEPT
iptables -I INPUT -p tcp -s 192.168.144.8 --dport 3306 -j ACCEPT
iptables-save > /etc/iptables/rules.v4

# Testing server
iptables -I INPUT -p tcp --dport 8085 -j ACCEPT
iptables -I INPUT -p tcp --dport 7878 -j ACCEPT
iptables-save > /etc/iptables/rules.v4
```

## Testing Connectivity

### From External Client
```bash
# Test authserver (production only)
nc -zv external.azerothcore.rollet.family 3724

# Test production worldserver
nc -zv external.azerothcore.rollet.family 8585

# Test testing worldserver
nc -zv external.azerothcore.rollet.family 8085
```

### Between Servers
```bash
# From production to testing worldserver
ssh root@azerothcore.rollet.family
nc -zv 192.168.144.8 8085

# From testing to production MySQL
ssh root@testing-azerothcore.rollet.family
nc -zv 192.168.144.7 3306
```

### Check Listening Ports
```bash
# Check what's listening on all interfaces
ss -tlnp | grep -E '(3724|8585|8085|7878|3306)'

# Or with netstat
netstat -tlnp | grep -E '(3724|8585|8085|7878|3306)'
```

## Security Considerations

1. **Testing Database Isolation**: Testing server's database (port 3306) is bound to localhost only (`127.0.0.1:3306`), preventing external access
2. **Shared Auth Read-Only**: Testing server connects to production authserver with read-only credentials
3. **Separate Networks**: Each server has its own Docker network (ac-network vs testing-ac-network)
4. **Port Segregation**: Different worldserver ports prevent accidental cross-connections (8585 vs 8085)

## Troubleshooting

### Port Already in Use
```bash
# Find what's using the port
lsof -i :8085
# or
ss -tlnp | grep 8085

# Kill the process if needed
kill <PID>
```

### Docker Port Not Accessible Externally
```bash
# Check Docker port mappings
docker ps | grep worldserver

# Check if Docker created iptables rules
iptables -t nat -L -n -v | grep 8085

# Check if host firewall is blocking
iptables -L -n -v | grep 8085
```

### Connection Refused from External IP
This usually indicates:
1. Firewall blocking the port
2. Docker not properly exposing the port
3. Application not listening on the port

Check in this order:
1. Verify app is listening: `ss -tlnp | grep PORT`
2. Verify Docker exposed port: `docker ps | grep worldserver`
3. Verify firewall allows port: `iptables -L -n -v | grep PORT`
4. Test from localhost first: `nc -zv 127.0.0.1 PORT`
5. Then test from external IP: `nc -zv EXTERNAL_IP PORT`

# lidguard

Mantiene la Mac trabajando con la tapa cerrada sin vaciar la batería.

Un daemon de launchd corre como root cada minuto:

- **Tapa abierta:** deja el sleep desactivado, así que cerrar la tapa no la duerme. El contador vuelve a cero.
- **Tapa cerrada:** empieza a contar. Pasadas `MAX_HOURS` (4 h por defecto), activa el sleep y la duerme.
- **A batería y por debajo de `MIN_BATTERY`** (20% por defecto): activa el sleep. Si la tapa está cerrada, la duerme en el momento.

## Uso

```
sudo ./lidguard install      # instala y arranca el daemon
lidguard status              # estado, config, batería
sudo lidguard hours 6        # cambia el límite con la tapa cerrada
sudo lidguard battery 30     # cambia el mínimo de batería
sudo lidguard off | on       # devuelve el sleep normal de macOS / lo vuelve a manejar
lidguard log                 # últimas acciones
sudo ./lidguard uninstall    # lo saca y restaura el sleep normal
```

- Config: `/etc/lidguard.conf`
- Log: `/var/log/lidguard.log`

## Limitación

Con un monitor externo y la tapa cerrada también corta a las `MAX_HOURS`. Si trabajás así, subí `hours` o hacé `off`.

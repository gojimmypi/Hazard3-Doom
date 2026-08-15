set {unsigned int}0x40009000 = 2    # Ensure any previous I2C transaction is terminated with STOP.
set {unsigned int}0x40009000 = 1    # Issue an I2C START condition and mark the bus active.
set {unsigned int}0x40009008 = 0xa8 # Load TXDATA with the 8-bit write address for 7-bit device 0x54 (0x54 << 1).
set {unsigned int}0x40009000 = 3    # Transmit the byte in TXDATA and sample the slave ACK/NACK response.
x/wx 0x40009004                     # Read STATUS; ACK is bit 2, NACK is bit 3, DONE is bit 1.
set {unsigned int}0x40009000 = 2    # Issue I2C STOP to end the probe transaction and release the bus.
x/wx 0x4000901c                     # Read LINES; 0x0f means SDA, SCL, GPIO1, and GPIO2 are all high/idle.

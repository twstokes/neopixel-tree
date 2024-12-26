## NeoPixel Tree DOS Application

### Build environment

- Install Open Watcom v2
- Download mTCP source
- Compile on a DOS machine (real or emulated) or cross-compile from a Windows machine (modern Windows works fine)

Example development flow:
1. Compile on modern Windows with `wmake`
2. Copy `xmastree.exe` to a shared HTTP server from the modern machine (see `sync.cmd` for a scripted example)
3. Download `xmastree.exe` to the DOS machine (see `download.bat` for a scripted example)
4. Execute binary

### Building

Due to the current MAKEFILE configuration it's easiest to put `TREE` under the `APPS` directory of the mTCP source.

- Run `wmake`

### Running

The binary must be executed in a DOS environment with a Packet Driver enabled. mTCP must be configured on the machine first, which includes:

- Initializing the packet driver (which will need to be downloaded for the attached NIC)
- Calling DHCP or setting up a static IP
- Confirming the tree can be reached and DNS lookups succeed

- Run `xmastree`

### Notes

- 86Box running in SLiRP mode worked fine for the DOS environment.

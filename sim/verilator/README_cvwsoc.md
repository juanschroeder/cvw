# CVWSOC simulation

The cvwsoc Makefile, testbench and Verilator wrapper .cpp file enables:
- QEMU-boot Yocto generated binaries for basic testing of the binaries
- Generation of 'preload' images to be used later for ROM/RAM preload (much faster verilation)
- QEMU-boot with the RAM image generated above to test that the contents of the image are correct
- Fully verilate system boot on a reduced CVWSOC (see details below). Serial console interaction is possible.
- Generate a full .fst trace of your run. The depth of the trace is limited to top signals by default because it needs a lot of disk space.


Remarks:
- This setup assumes by default a Yocto build output ('deploy' folder) of the 'cvwsoc-virt' MACHINE and the 'tiny' image. See 'kas-cvwsoc' repo (https://github.com/juanschroeder/kas-cvwsoc)
    * There's a default path used. CVWSOC_DEPLOY_ROOT *must* be overridden from the command line.
- Verilation testbench creates a /dev/pts/nn serial interface where serial output and also INPUT can be handled
- all targets above allow to do the boot on OpenSBI->Linux and OpenSBI->U-boot->Linux. For only u-boot the user needs to press a key during u-boot.
- There are lots of parameters that can be overridden from the command line, too many to mention here.
- Verilation speed in Mhz is printed in the UART outputs (shell, or .out file, not in /dev/pts/.. one)
- For the moment RAM images are 1 GB in size, so for 'playing' with linux and u-boot at least 2GB are needed.
- Currently a .cpio initrd image is assumed because it was found to be the fastest. But this needs to be investigated further.
- Trace generation slows down simulation, so it is disabled by default.


# Known issues and limitations:
- Using THREADS > 1 makes simulation SLOWER.
- The serial interface needs always an extra character to be entered for the previous one to be sent. To be fixed soon.
- The runcmd-* targets, which should run a command on the shell as soon as the prompt is reached, are not fully working yet


# Dependencies:
- verilator (tested: v5.036)

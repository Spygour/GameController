# GAMECONTROLLER

## Main scope
Main scope of the project is to control the fpga in order to generate image through vga connector to a screen. The main written hardware designed on the fpga will be used especially for generation of first person type of game. <br>
All of this can be achived by the communication between two devices: An *Altera's Cyclone IV Fpga* and an *Infineon's Tricore Aurix 275 microcontroller*.<br>**Nevertheless, some extra components were used to test this project and they can be seen on the next table.**<br>
| Components | Amount | Extra infomation |
|:------|:-----:|------:|
| Waveshare Vga module | 1 | It contains some pins and can<br> be easily checked on their site |
| SparkFun Level Shifter - 8 Channel (TXS0108E)  | 4 | Perfect for really  <br>high speed level shift |
| Resistors  | 51 | Can be used as 3 ladders <br> of 8 bits **green blue red** |
| External power supply | 1 | Maximum 1 Ampere and 5 Volts <br> Provides voltage to the <br> transformers and the vga module  |
| Screen with vga connector | 1 | CRT screens are the most <br>well known for their vga connector |


## Quad Spi
Main purpose of the aurix is to control the fpga using quad spi protocol. <br>
The microcontroller has not actual quad spi but instead it uses a customized ddr serial protocol of 5 outputs.<br>
Why 5 outputs? We are trying to demonstate a synchronous communication of a ddr clock (writes on both ups and downs) and chip select usage like spi. The idea came after analysing the behavior of the sdram that its hardware driver was written inside the project<br>
Aurix provides the ***Gtm module*** which can generates up to 15 pwms at the same time controlled by a single timer on really high speed <br>With ***Atom's serial mode*** we can provide bitframes of 16 bits by updating the atom timers ***CM0*** register provide data from actual softwares buffer to shadow register ***SR0*** inside an interrupt. <br> The amount of achieved speed was 10 mhz. Interrupt was triggered every 16 bits of the 10 mhz, so the interrupt's frequency was about 600 khz.<br> 
To avoid extra cpu load due to the interrupt Dma was used as daisy chain with increment mode to provide data from the software buffer inside the shadow register.<br> Isr works as a observer during the operation in order to provide to the main tasks the information that transcaction is complete. <br>
Next steps are the **FreeRTOS** integration and the creation of a main task that provides to fpga the starting image depends of users position on the map. This will be mentioned afterwards on the **Main Application** chapter.
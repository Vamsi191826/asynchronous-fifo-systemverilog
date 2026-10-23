# async_fifo.xdc
# Timing constraints for Asynchronous FIFO CDC design
# Target example:
#   wclk = 100 MHz -> 10 ns period
#   rclk = 50 MHz  -> 20 ns period

create_clock -name wclk -period 10.000 [get_ports wclk]
create_clock -name rclk -period 20.000 [get_ports rclk]

# wclk and rclk are independent asynchronous clock domains.
# Do not time paths directly between these two unrelated clocks.
set_clock_groups -asynchronous \
    -group [get_clocks wclk] \
    -group [get_clocks rclk]

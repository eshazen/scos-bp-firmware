def set_dac_voltage(volts, gain=1):
    """Set the nominal output voltage; gain is 1 or 2."""
    if gain not in (1, 2):
        raise ValueError("gain must be 1 or 2")
    if volts < 0:
        raise ValueError("volts cannot be negative")

    full_scale = 2.048 * gain
    code = round(volts * 4096 / full_scale)
    set_dac_code(min(code, 4095), gain)

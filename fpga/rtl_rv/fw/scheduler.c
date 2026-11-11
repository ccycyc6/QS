/*
 * ScreenSense - RISC-V frame scheduler (option B)
 *
 * The core is not a vision processor.  It only sequences the frame stream:
 *   read the frame-level argmax result -> debounce -> publish a gate bit.
 *
 * Registers live in the SoC's shared uncached MMIO window (0xA000F0xx),
 * implemented by rv_mmio.v -- no ARES source is modified.
 */

#define REG(a)      (*(volatile unsigned int *)(a))

#define R_PKT       0xA000F000u   /* {cls[31:24], x[23:16], y[15:8], conf[7:0]} */
#define R_SEQ       0xA000F004u   /* increments once per new detection         */
#define R_VALID     0xA000F008u   /* sticky: any detection seen                */
#define R_CNT       0xA000F00Cu   /* detections in the last frame              */
#define R_CTRL      0xA000F010u   /* bit0 = gate_enable                        */

/* How many consecutive frames must agree before the gate opens. */
#define STABLE_FRAMES 3u

int main(void)
{
    unsigned last_seq = 0;
    unsigned cls      = 0;
    unsigned stable   = 0;
    unsigned gate     = 0;

    REG(R_CTRL) = 0;

    for (;;) {
        unsigned seq = REG(R_SEQ);

        if (seq != last_seq) {
            unsigned pkt, c, cnt;

            last_seq = seq;
            pkt      = REG(R_PKT);
            cnt      = REG(R_CNT);
            c        = (pkt >> 24) & 0xFFu;

            if (cnt == 0u) {
                /* nothing detected this frame: drop the candidate */
                stable = 0;
                gate   = 0;
            } else if (c == cls) {
                if (stable < STABLE_FRAMES)
                    stable++;
            } else {
                cls    = c;
                stable = 0;
            }

            if (stable >= STABLE_FRAMES)
                gate = 1;

            REG(R_CTRL) = gate;
        }
    }

    return 0;
}

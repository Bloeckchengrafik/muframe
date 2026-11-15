package wishbone_pkg;
    typedef struct packed {
        logic        cyc;
        logic        stb;
        logic        we;
        logic [31:0] adr;
        logic [31:0] dat;
        logic [3:0]  sel;
    } wb_h2d_t;
    typedef struct packed {
        logic        ack;
        logic        err;
        logic [31:0] dat;
    } wb_d2h_t;
endpackage

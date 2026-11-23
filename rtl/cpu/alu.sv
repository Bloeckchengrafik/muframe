package alu_pkg;
    typedef enum logic [4:0] {
        PASS_A = 0,
        ADD = 1,
        SUB = 2,
        AND = 3,
        OR = 4,
        XOR = 5,
        NOT_A = 6,
        SHL = 7,
        SHR = 8,
        SAR = 9,
        ROL = 10,
        ROR = 11,
        ADC = 12,
        SBC = 13,
        SEXT8 = 14,
        SEXT16 = 15,
        ZEXT8 = 16,
        ZEXT16 = 17,
        SWAP16 = 18,
        BSWAP = 19
    } alu_op_t;

    typedef enum logic [3:0] {
        NIBBLE = 0,
        BYTE = 1,
        HWORD = 2,
        WORD = 3
    } alu_width_t;

    typedef struct packed {
        logic negative;
        logic zero;
        logic carry;
        logic overflow;
    } alu_flags_t;
endpackage

module alu(
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  alu_op_t     alu_op_i,
    input  alu_width_t  alu_width_i,
    output logic [31:0] result_o,

    input  alu_flags_t  flags_i,
    output alu_flags_t  flags_o
);
    always_comb begin
        
    end
end

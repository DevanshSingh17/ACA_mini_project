package MatMul;

import Vector   :: *;
import FIFOF    :: *;
import MM_Types :: *;


// ================================================================
// DESIGN C
// K-SERIAL MATRIX MULTIPLICATION WITH DOUBLE BUFFERING
//
// Two A/B banks are used:
//
//     Bank 0 : A0, B0
//     Bank 1 : A1, B1
//
// While one bank is being used for computation, the other bank
// can be loaded with the next matrix tile.
//
//
//
// Example:
//
//     active_bank = 0
//
//         Bank 0  ---> COMPUTE
//         Bank 1  <--- LOAD
//
//     After computation:
//
//         active_bank = 1
//
//         Bank 1  ---> COMPUTE
//         Bank 0  <--- LOAD
//
//
// K-serial computation:
//
//     K = 0
//     K = 1
//     K = 2
//     K = 3
//
// Each K cycle performs:
//
//     16 multiplications
//     16 accumulator additions
//
// ================================================================


(* synthesize *)
module mkMatMul (MatMul_IFC);


   // =============================================================
   // BANK 0
   // =============================================================

   Reg #(A_Mat) rg_a0 <- mkReg (replicate (replicate (0)));

   Reg #(B_Mat) rg_b0 <- mkReg (replicate (replicate (0)));


   // =============================================================
   // BANK 1
   // =============================================================

   Reg #(A_Mat) rg_a1 <- mkReg (replicate (replicate (0)));

   Reg #(B_Mat) rg_b1 <- mkReg (replicate (replicate (0)));


   // =============================================================
   // OUTPUT / ACCUMULATOR
   // =============================================================

   Reg #(C_Mat) rg_c <- mkReg (replicate (replicate (0)));


   // =============================================================
   // REQUEST / RESPONSE FIFOs
   // =============================================================

   FIFOF #(MM_Req) f_req <- mkFIFOF;

   FIFOF #(MM_Rsp) f_rsp <- mkFIFOF;


   // =============================================================
   // MULTIPLICATION STATE
   // =============================================================

   // False = no multiplication running
   // True  = multiplication running

   Reg #(Bool) rg_busy <- mkReg (False);


   // =============================================================
   // ACTIVE BANK
   // =============================================================
   //
   // False -> Bank 0 is active
   // True  -> Bank 1 is active
   //
   // During computation:
   //
   //     active bank   = COMPUTE
   //     other bank    = LOAD
   //
   // =============================================================

   Reg #(Bool) rg_active_bank <- mkReg (False);


   // =============================================================
   // K INDEX
   // =============================================================

   Reg #(Bit #(2)) rg_k <- mkReg (0);


   // =============================================================
   // LOAD A INTO BANK 0 WHILE IDLE
   // =============================================================
   //
   // Bank 0 is active when idle and active_bank = 0.
   //
   // This is used for loading the initial tile into Bank 0.
   //
   // =============================================================

   rule rl_load_a0_idle
      (!rg_busy &&& !rg_active_bank
       &&& f_req.first matches tagged LoadA .w);

      f_req.deq;

      A_Mat a = rg_a0;

      a[w.row] = reverse (unpack (w.word));

      rg_a0 <= a;

      f_rsp.enq (mm_rsp_none);

   endrule


   // =============================================================
   // LOAD A INTO BANK 1 WHILE IDLE
   // =============================================================

   rule rl_load_a1_idle
      (!rg_busy &&& rg_active_bank
       &&& f_req.first matches tagged LoadA .w);

      f_req.deq;

      A_Mat a = rg_a1;

      a[w.row] = reverse (unpack (w.word));

      rg_a1 <= a;

      f_rsp.enq (mm_rsp_none);

   endrule


   // =============================================================
   // LOAD A INTO BANK 0 WHILE BANK 1 IS COMPUTING
   // =============================================================
   //
   // active_bank = 1
   //
   // Therefore Bank 0 is the inactive bank and can be loaded.
   //
   // This rule can execute simultaneously with the Bank 1
   // multiplication rule.
   //
   // =============================================================

   rule rl_load_a0_busy
      (rg_busy &&& rg_active_bank
       &&& f_req.first matches tagged LoadA .w);

      f_req.deq;

      A_Mat a = rg_a0;

      a[w.row] = reverse (unpack (w.word));

      rg_a0 <= a;

      f_rsp.enq (mm_rsp_none);

   endrule


   // =============================================================
   // LOAD A INTO BANK 1 WHILE BANK 0 IS COMPUTING
   // =============================================================
   //
   // active_bank = 0
   //
   // Therefore Bank 1 is the inactive bank and can be loaded.
   //
   // =============================================================

   rule rl_load_a1_busy
      (rg_busy &&& !rg_active_bank
       &&& f_req.first matches tagged LoadA .w);

      f_req.deq;

      A_Mat a = rg_a1;

      a[w.row] = reverse (unpack (w.word));

      rg_a1 <= a;

      f_rsp.enq (mm_rsp_none);

   endrule


   // =============================================================
   // LOAD B INTO BANK 0 WHILE IDLE
   // =============================================================

   rule rl_load_b0_idle
      (!rg_busy &&& !rg_active_bank
       &&& f_req.first matches tagged LoadB .w);

      f_req.deq;

      B_Mat b = rg_b0;

      b[w.row] = reverse (unpack (w.word));

      rg_b0 <= b;

      f_rsp.enq (mm_rsp_none);

   endrule


   // =============================================================
   // LOAD B INTO BANK 1 WHILE IDLE
   // =============================================================

   rule rl_load_b1_idle
      (!rg_busy &&& rg_active_bank
       &&& f_req.first matches tagged LoadB .w);

      f_req.deq;

      B_Mat b = rg_b1;

      b[w.row] = reverse (unpack (w.word));

      rg_b1 <= b;

      f_rsp.enq (mm_rsp_none);

   endrule


   // =============================================================
   // LOAD B INTO BANK 0 WHILE BANK 1 IS COMPUTING
   // =============================================================

   rule rl_load_b0_busy
      (rg_busy &&& rg_active_bank
       &&& f_req.first matches tagged LoadB .w);

      f_req.deq;

      B_Mat b = rg_b0;

      b[w.row] = reverse (unpack (w.word));

      rg_b0 <= b;

      f_rsp.enq (mm_rsp_none);

   endrule


   // =============================================================
   // LOAD B INTO BANK 1 WHILE BANK 0 IS COMPUTING
   // =============================================================

   rule rl_load_b1_busy
      (rg_busy &&& !rg_active_bank
       &&& f_req.first matches tagged LoadB .w);

      f_req.deq;

      B_Mat b = rg_b1;

      b[w.row] = reverse (unpack (w.word));

      rg_b1 <= b;

      f_rsp.enq (mm_rsp_none);

   endrule


   // =============================================================
   // START MULTIPLICATION
   // =============================================================
   //
   // K = 0 is calculated in the same cycle as the Mul request.
   //
   // Therefore:
   //
   //     Cycle 1 -> K = 0
   //     Cycle 2 -> K = 1
   //     Cycle 3 -> K = 2
   //     Cycle 4 -> K = 3
   //
   // =============================================================

   rule rl_mul_start
      (!rg_busy &&& f_req.first matches tagged Mul);

      f_req.deq;


      C_Mat c = rg_c;


      // =========================================================
      // BANK 0 ACTIVE
      // =========================================================

      if (!rg_active_bank) begin

         for (Integer i = 0; i < m_dim; i = i + 1)

            for (Integer j = 0; j < n_dim; j = j + 1)

               c[i][j] =
                  c[i][j]
                  + (signExtend (rg_a0[i][0])
                     * signExtend (rg_b0[0][j]));

      end


      // =========================================================
      // BANK 1 ACTIVE
      // =========================================================

      else begin

         for (Integer i = 0; i < m_dim; i = i + 1)

            for (Integer j = 0; j < n_dim; j = j + 1)

               c[i][j] =
                  c[i][j]
                  + (signExtend (rg_a1[i][0])
                     * signExtend (rg_b1[0][j]));

      end


      // Save K = 0 result.
      rg_c <= c;


      // Multiplication now running.
      rg_busy <= True;


      // Next cycle = K = 1.
      rg_k <= 1;


      // Response for Mul.
      f_rsp.enq (mm_rsp_none);

   endrule


   // =============================================================
   // MULTIPLY BANK 0
   // =============================================================
   //
   // Bank 0 is active.
   //
   // At the same time:
   //
   //     rl_load_a1_busy
   //     rl_load_b1_busy
   //
   // may load Bank 1.
   //
   // =============================================================

   rule rl_mul_bank0
      (rg_busy &&& !rg_active_bank);

      C_Mat c = rg_c;


      for (Integer i = 0; i < m_dim; i = i + 1)

         for (Integer j = 0; j < n_dim; j = j + 1)

            c[i][j] =
               c[i][j]
               + (signExtend (rg_a0[i][rg_k])
                  * signExtend (rg_b0[rg_k][j]));


      rg_c <= c;


      if (rg_k == 3) begin

         // Finished current tile.
         rg_busy <= False;

         // Bank 1 becomes active.
         rg_active_bank <= True;

      end
      else begin

         rg_k <= rg_k + 1;

      end

   endrule


   // =============================================================
   // MULTIPLY BANK 1
   // =============================================================
   //
   // Bank 1 is active.
   //
   // At the same time:
   //
   //     rl_load_a0_busy
   //     rl_load_b0_busy
   //
   // may load Bank 0.
   //
   // =============================================================

   rule rl_mul_bank1
      (rg_busy &&& rg_active_bank);

      C_Mat c = rg_c;


      for (Integer i = 0; i < m_dim; i = i + 1)

         for (Integer j = 0; j < n_dim; j = j + 1)

            c[i][j] =
               c[i][j]
               + (signExtend (rg_a1[i][rg_k])
                  * signExtend (rg_b1[rg_k][j]));


      rg_c <= c;


      if (rg_k == 3) begin

         // Finished current tile.
         rg_busy <= False;

         // Bank 0 becomes active.
         rg_active_bank <= False;

      end
      else begin

         rg_k <= rg_k + 1;

      end

   endrule


   // =============================================================
   // READ C
   // =============================================================
   //
   // ReadC is only allowed when multiplication is finished.
   //
   // =============================================================

   rule rl_read_c
      (!rg_busy &&& f_req.first matches tagged ReadC .x);

      f_req.deq;

      C_Mat c = rg_c;

      Acc v = c[x.row][x.chunk];


      // ReadC consumes the element.
      c[x.row][x.chunk] = 0;

      rg_c <= c;


      f_rsp.enq (mm_rsp_value (pack (v)));

   endrule


   // =============================================================
   // INTERFACE
   // =============================================================

   method Action req (MM_Req r);

      f_req.enq (r);

   endmethod


   method ActionValue #(MM_Rsp) rsp;

      f_rsp.deq;

      return f_rsp.first;

   endmethod


endmodule

endpackage
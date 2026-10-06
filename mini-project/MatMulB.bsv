package MatMul;

import Vector   :: *;
import FIFOF    :: *;
import MM_Types :: *;


// ================================================================
// DESIGN B
// K-SERIAL MATRIX MULTIPLICATION
//
// 4x4 matrix multiplication:
//
// C[i][j] += A[i][0]*B[0][j]
//          + A[i][1]*B[1][j]
//          + A[i][2]*B[2][j]
//          + A[i][3]*B[3][j]
//
// Design A:
//     All 4 K terms are calculated in one cycle.
//     64 multiplications in the Mul operation.
//
// Design B:
//     One K slice is calculated per cycle.
//
//     Each computation cycle:
//
//         16 multiplications
//         16 accumulator additions
//
//     Total:
//
//         4 computation cycles per Mul
//
// ================================================================


(* synthesize *)
module mkMatMul (MatMul_IFC);


   // =============================================================
   // MATRIX STORAGE
   // =============================================================

   Reg #(A_Mat) rg_a <- mkReg (replicate (replicate (0)));

   Reg #(B_Mat) rg_b <- mkReg (replicate (replicate (0)));

   Reg #(C_Mat) rg_c <- mkReg (replicate (replicate (0)));


   // =============================================================
   // REQUEST / RESPONSE FIFOs
   // =============================================================

   FIFOF #(MM_Req) f_req <- mkFIFOF;

   FIFOF #(MM_Rsp) f_rsp <- mkFIFOF;


   // =============================================================
   // MULTIPLICATION STATE
   // =============================================================

   // rg_busy = False
   //     Normal operation.
   //
   // rg_busy = True
   //     A Mul operation is currently in progress.
   //
   // While busy:
   //
   //     LoadA  -> blocked
   //     LoadB  -> blocked
   //     Mul    -> blocked
   //     ReadC  -> blocked
   //
   // This prevents A/B from changing during multiplication.

   Reg #(Bool) rg_busy <- mkReg (False);


   // Current K index.
   //
   // 0 -> A[i][0] * B[0][j]
   // 1 -> A[i][1] * B[1][j]
   // 2 -> A[i][2] * B[2][j]
   // 3 -> A[i][3] * B[3][j]

   Reg #(Bit #(2)) rg_k <- mkReg (0);


   // =============================================================
   // LOAD A
   // =============================================================

   rule rl_load_a
      (!rg_busy &&& f_req.first matches tagged LoadA .w);

      f_req.deq;

      A_Mat a = rg_a;

      a[w.row] = reverse (unpack (w.word));

      rg_a <= a;

      // One response for every request.
      f_rsp.enq (mm_rsp_none);

   endrule


   // =============================================================
   // LOAD B
   // =============================================================

   rule rl_load_b
      (!rg_busy &&& f_req.first matches tagged LoadB .w);

      f_req.deq;

      B_Mat b = rg_b;

      b[w.row] = reverse (unpack (w.word));

      rg_b <= b;

      // One response for every request.
      f_rsp.enq (mm_rsp_none);

   endrule


   // =============================================================
   // START MULTIPLICATION
   // =============================================================
   //
   // The Mul request performs K = 0 immediately.
   //
   // Therefore:
   //
   //     Mul cycle 1 -> K = 0
   //     Mul cycle 2 -> K = 1
   //     Mul cycle 3 -> K = 2
   //     Mul cycle 4 -> K = 3
   //
   // Total = exactly 4 computation cycles.
   //
   // =============================================================

   rule rl_mul_start
      (!rg_busy &&& f_req.first matches tagged Mul);

      f_req.deq;


      // -----------------------------------------------------------
      // Perform K = 0
      //
      // C[i][j] += A[i][0] * B[0][j]
      // -----------------------------------------------------------

      C_Mat c = rg_c;

      for (Integer i = 0; i < m_dim; i = i + 1)

         for (Integer j = 0; j < n_dim; j = j + 1)

            c[i][j] =
               c[i][j]
               + (signExtend (rg_a[i][0])
                  * signExtend (rg_b[0][j]));


      // Store result of K = 0.
      rg_c <= c;


      // -----------------------------------------------------------
      // Multiplication is now busy.
      //
      // Next cycle will calculate K = 1.
      // -----------------------------------------------------------

      rg_busy <= True;

      rg_k <= 1;


      // Every request gets exactly one response.
      f_rsp.enq (mm_rsp_none);

   endrule


   // =============================================================
   // K-SERIAL MULTIPLICATION STEP
   // =============================================================
   //
   // This rule performs:
   //
   //     C[i][j] += A[i][k] * B[k][j]
   //
   // for all 16 output elements.
   //
   // It executes for:
   //
   //     K = 1
   //     K = 2
   //     K = 3
   //
   // K = 0 was already performed by rl_mul_start.
   //
   // Therefore the complete Mul operation takes:
   //
   //     1 cycle : K = 0
   //     1 cycle : K = 1
   //     1 cycle : K = 2
   //     1 cycle : K = 3
   //
   //             --------
   //             4 cycles
   //
   // =============================================================

   rule rl_mul_step (rg_busy);

      C_Mat c = rg_c;


      // -----------------------------------------------------------
      // Calculate one K slice for the complete 4x4 matrix.
      // -----------------------------------------------------------

      for (Integer i = 0; i < m_dim; i = i + 1)

         for (Integer j = 0; j < n_dim; j = j + 1)

            c[i][j] =
               c[i][j]
               + (signExtend (rg_a[i][rg_k])
                  * signExtend (rg_b[rg_k][j]));


      // Store updated accumulator matrix.
      rg_c <= c;


      // -----------------------------------------------------------
      // Check whether this was the final K slice.
      // -----------------------------------------------------------

      if (rg_k == 3) begin

         // K = 3 is the final computation.
         rg_busy <= False;

      end
      else begin

         // Move to next K slice.
         rg_k <= rg_k + 1;

      end

   endrule


   // =============================================================
   // READ C
   // =============================================================
   //
   // Return:
   //
   //     C[row][chunk]
   //
   // and clear that element afterwards.
   //
   // ReadC is blocked while multiplication is active.
   //
   // =============================================================

   rule rl_read_c
      (!rg_busy &&& f_req.first matches tagged ReadC .x);

      f_req.deq;

      C_Mat c = rg_c;

      Acc v = c[x.row][x.chunk];


      // ReadC consumes the C element.
      c[x.row][x.chunk] = 0;

      rg_c <= c;


      // Return the accumulator value.
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
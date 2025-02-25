// RUN: mlir-opt %s -linalg-tile="linalg-tile-sizes=2,3,4" -split-input-file | FileCheck %s
// RUN: mlir-opt %s -linalg-tile-to-tiled-loop="linalg-tile-sizes=2,3,4 linalg-distribution-types=block_x,block_y,none" -split-input-file | FileCheck %s -check-prefix=TLOOP

// CHECK-LABEL: func @matmul_tensors(
// CHECK-SAME:    %[[TA:[0-9a-z]+]]: tensor<?x?xf32>
// CHECK-SAME:    %[[TB:[0-9a-z]+]]: tensor<?x?xf32>
// CHECK-SAME:    %[[TC:[0-9a-z]+]]: tensor<?x?xf32>) -> tensor<?x?xf32> {
func @matmul_tensors(
  %arg0: tensor<?x?xf32>, %arg1: tensor<?x?xf32>, %arg2: tensor<?x?xf32>)
    -> tensor<?x?xf32> {
//      CHECK: %[[TD0:.*]] = scf.for {{.*}} to {{.*}} step {{.*}} iter_args(%[[TC0:.*]] = %[[TC]]) -> (tensor<?x?xf32>) {
//      CHECK:   %[[TD1:.*]] = scf.for {{.*}} to {{.*}} step {{.*}} iter_args(%[[TC1:.*]] = %[[TC0]]) -> (tensor<?x?xf32>) {
//      CHECK:     %[[TD2:.*]] = scf.for {{.*}} to {{.*}} step {{.*}} iter_args(%[[TC2:.*]] = %[[TC1]]) -> (tensor<?x?xf32>) {
//      CHECK:       %[[sTA:.*]] = tensor.extract_slice %[[TA]][{{.*}}] : tensor<?x?xf32> to tensor<?x?xf32>
//      CHECK:       %[[sTB:.*]] = tensor.extract_slice %[[TB]][{{.*}}] : tensor<?x?xf32> to tensor<?x?xf32>
//      CHECK:       %[[sTC:.*]] = tensor.extract_slice %[[TC2]][{{.*}}] : tensor<?x?xf32> to tensor<?x?xf32>
//      CHECK:       %[[sTD:.*]] = linalg.matmul ins(%[[sTA]], %[[sTB]] : tensor<?x?xf32>, tensor<?x?xf32>)
// CHECK-SAME:                                  outs(%[[sTC]] : tensor<?x?xf32>)  -> tensor<?x?xf32>
//      CHECK:       %[[TD:.*]] = tensor.insert_slice %[[sTD]] into %[[TC2]][{{.*}}]  : tensor<?x?xf32> into tensor<?x?xf32>
//      CHECK:       scf.yield %[[TD]] : tensor<?x?xf32>
//      CHECK:     scf.yield %[[TD2]] : tensor<?x?xf32>
//      CHECK:   scf.yield %[[TD1]] : tensor<?x?xf32>
  %0 = linalg.matmul  ins(%arg0, %arg1: tensor<?x?xf32>, tensor<?x?xf32>)
                     outs(%arg2: tensor<?x?xf32>)
    -> tensor<?x?xf32>

//      CHECK: return %[[TD0]] : tensor<?x?xf32>
  return %0 : tensor<?x?xf32>
}

// TLOOP-LABEL: func @matmul_tensors
// TLOOP-SAME: (%[[ARG_0:.*]]: [[TY:.*]], %[[ARG_1:.*]]: [[TY]],
// TLOOP-SAME: %[[ARG_2:.*]]: [[TY]]) -> [[TY]] {

// TLOOP-DAG: %[[C0:.*]] = constant 0 : index
// TLOOP-DAG: %[[C1:.*]] = constant 1 : index
// TLOOP-DAG: %[[C2:.*]] = constant 2 : index
// TLOOP-DAG: %[[C3:.*]] = constant 3 : index
// TLOOP-DAG: %[[C4:.*]] = constant 4 : index

// TLOOP: %[[ARG_0_X:.*]] = memref.dim %[[ARG_0]], %[[C0]] : [[TY]]
// TLOOP: %[[ARG_0_Y:.*]] = memref.dim %[[ARG_0]], %[[C1]] : [[TY]]
// TLOOP: %[[ARG_1_Y:.*]] = memref.dim %[[ARG_1]], %[[C1]] : [[TY]]

// TLOOP: %{{.*}} = linalg.tiled_loop (%[[I:.*]], %[[J:.*]], %[[K:.*]]) =
// TLOOP-SAME: (%[[C0]], %[[C0]], %[[C0]])
// TLOOP-SAME: to (%[[ARG_0_X]], %[[ARG_1_Y]], %[[ARG_0_Y]])
// TLOOP-SAME: step (%[[C2]], %[[C3]], %[[C4]])
// TLOOP-SAME: ins (%[[A0:.*]] = %[[ARG_0]]: [[TY]], %[[A1:.*]] = %[[ARG_1]]: [[TY]])
// TLOOP-SAME: outs (%[[A2:.*]] = %[[ARG_2]]: [[TY]])
// TLOOP-SAME: iterators["parallel", "parallel", "reduction"]
// TLOOP-SAME: distribution["block_x", "block_y", "none"] {

// TLOOP: %[[SUB_ARG_0:.*]] = tensor.extract_slice %[[A0]][%[[I]], %[[K]]]
// TLOOP: %[[SUB_ARG_1:.*]] = tensor.extract_slice %[[A1]][%[[K]], %[[J]]]
// TLOOP: %[[SUB_ARG_2:.*]] = tensor.extract_slice %[[A2]][%[[I]], %[[J]]]

// TLOOP: %[[PROD:.*]] = linalg.matmul ins(%[[SUB_ARG_0]], %[[SUB_ARG_1]]
// TLOOP-SE: outs(%[[SUB_ARG_2]] : [[TY]]) -> [[TY]]

// TLOOP: %[[O:.*]] = tensor.insert_slice %[[PROD]] into %[[A2]][%[[I]], %[[J]]]
// TLOOP: linalg.yield %[[O]] : [[TY]]

// -----

func @generic_op_tensors(
  %arg0 : tensor<?x?x?xf32>, %arg1 : tensor<?x?x?xf32>) -> tensor<?x?x?xf32> {
  %c0 = constant 0 : index
  %c1 = constant 1 : index
  %c2 = constant 2 : index
  %0 = memref.dim %arg0, %c0 : tensor<?x?x?xf32>
  %1 = memref.dim %arg0, %c1 : tensor<?x?x?xf32>
  %2 = memref.dim %arg0, %c2 : tensor<?x?x?xf32>
  %3 = linalg.init_tensor [%0, %1, %2] : tensor<?x?x?xf32>
  %4 = linalg.generic
    {indexing_maps = [affine_map<(d0, d1, d2) -> (d0, d1, d2)>,
                      affine_map<(d0, d1, d2) -> (d0, d2, d1)>,
                      affine_map<(d0, d1, d2) -> (d2, d1, d0)>],
     iterator_types = ["parallel", "parallel", "parallel"]}
    ins(%arg0, %arg1 : tensor<?x?x?xf32>, tensor<?x?x?xf32>)
    outs(%3 : tensor<?x?x?xf32>) {
    ^bb0(%arg2 : f32, %arg3: f32, %arg4: f32):
      %5 = addf %arg2, %arg3 : f32
      linalg.yield %5 : f32
    } -> tensor<?x?x?xf32>
  return %4 : tensor<?x?x?xf32>
}

// CHECK-LABEL: func @generic_op_tensors
//  CHECK-SAME:   %[[ARG0:[a-zA-Z0-9_]+]]: tensor<?x?x?xf32>
//  CHECK-SAME:   %[[ARG1:[a-zA-Z0-9_]+]]: tensor<?x?x?xf32>
//       CHECK:   %[[INIT:.+]] = linalg.init_tensor
//       CHECK:   %[[TD0:.+]] = scf.for %{{.+}} to %{{.+}} step %{{.+}} iter_args(%[[TC0:.+]] = %[[INIT]]) -> (tensor<?x?x?xf32>) {
//       CHECK:     %[[TD1:.+]] = scf.for %{{.+}} to %{{.+}} step %{{.+}} iter_args(%[[TC1:.+]] = %[[TC0]]) -> (tensor<?x?x?xf32>) {
//       CHECK:       %[[TD2:.+]] = scf.for %{{.+}} to %{{.+}} step %{{.+}} iter_args(%[[TC2:.+]] = %[[TC1]]) -> (tensor<?x?x?xf32>) {
//       CHECK:       %[[STARG0:.+]] = tensor.extract_slice %[[ARG0]][{{.+}}] : tensor<?x?x?xf32> to tensor<?x?x?xf32>
//       CHECK:       %[[STARG1:.+]] = tensor.extract_slice %[[ARG1]][{{.+}}] : tensor<?x?x?xf32> to tensor<?x?x?xf32>
//       CHECK:       %[[STARG2:.+]] = tensor.extract_slice %[[TC2]][{{.+}}] : tensor<?x?x?xf32> to tensor<?x?x?xf32>
//       CHECK:       %[[STRETURN:.+]] = linalg.generic
//  CHECK-SAME:         ins(%[[STARG0]], %[[STARG1]] : tensor<?x?x?xf32>, tensor<?x?x?xf32>)
//  CHECK-SAME:         outs(%[[STARG2]] : tensor<?x?x?xf32>)
//       CHECK:       %[[TD:.+]] = tensor.insert_slice %[[STRETURN]] into %[[TC2]]
//       CHECK:       scf.yield %[[TD]]
//       CHECK:     }
//       CHECK:     scf.yield %[[TD2]]
//       CHECK:   }
//       CHECK:   scf.yield %[[TD1]]
//       CHECK: }
//       CHECK: return %[[TD0]]

// TLOOP-LABEL: func @generic_op_tensors(
// TLOOP-SAME:    %[[ARG_0:.*]]: [[TY:.*]],
// TLOOP-SAME:    %[[ARG_1:.*]]: [[TY]]) -> [[TY]] {

// TLOOP-DAG: %[[C0:.*]] = constant 0 : index
// TLOOP-DAG: %[[C1:.*]] = constant 1 : index
// TLOOP-DAG: %[[C2:.*]] = constant 2 : index
// TLOOP-DAG: %[[C3:.*]] = constant 3 : index
// TLOOP-DAG: %[[C4:.*]] = constant 4 : index

// TLOOP:     %[[INIT:.*]] = linalg.init_tensor
// TLOOP:     %[[ARG_0_X:.*]] = memref.dim %[[ARG_0]], %[[C0]] : [[TY]]
// TLOOP:     %[[ARG_0_Y:.*]] = memref.dim %[[ARG_0]], %[[C1]] : [[TY]]
// TLOOP:     %[[ARG_0_Z:.*]] = memref.dim %[[ARG_0]], %[[C2]] : [[TY]]

// TLOOP:     %{{.*}} = linalg.tiled_loop (%{{.*}}, %{{.*}}, %{{.*}}) =
// TLOOP-SAME: (%[[C0]], %[[C0]], %[[C0]])
// TLOOP-SAME: to (%[[ARG_0_X]], %[[ARG_0_Y]], %[[ARG_0_Z]])
// TLOOP-SAME: step (%[[C2]], %[[C3]], %[[C4]])
// TLOOP-SAME: ins (%{{.*}} = %[[ARG_0]]: [[TY]], %{{.*}} = %[[ARG_1]]: [[TY]])
// TLOOP-SAME: outs (%{{.*}} = %[[INIT]]: [[TY]])
// TLOOP-SAME: distribution["block_x", "block_y", "none"] {


func @fill(%arg0 : tensor<?x?x?xf32>) -> tensor<?x?x?xf32> {
 %c0 = constant 0.0 : f32
 %0 = linalg.fill(%c0, %arg0) : f32, tensor<?x?x?xf32> -> tensor<?x?x?xf32>
 return %0 : tensor<?x?x?xf32>
}
// CHECK-LABEL: func @fill

// TLOOP-LABEL: func @fill
// TLOOP-NOT: ins
// TLOOP: tensor.extract_slice
// TLOOP-NEXT: linalg.fill
// TLOOP-NEXT: tensor.insert_slice

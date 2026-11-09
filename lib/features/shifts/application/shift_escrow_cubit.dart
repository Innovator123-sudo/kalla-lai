import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';

class ShiftWorkflowState extends Equatable {
  const ShiftWorkflowState({
    required this.ledger,
    this.dispatchStatus = DispatchStatus.confirmed,
  });

  final LedgerEntry ledger;
  final DispatchStatus dispatchStatus;

  ShiftWorkflowState copyWith({
    LedgerEntry? ledger,
    DispatchStatus? dispatchStatus,
  }) => ShiftWorkflowState(
    ledger: ledger ?? this.ledger,
    dispatchStatus: dispatchStatus ?? this.dispatchStatus,
  );

  @override
  List<Object> get props => [ledger, dispatchStatus];
}

class ShiftEscrowCubit extends Cubit<ShiftWorkflowState> {
  ShiftEscrowCubit(LedgerEntry initialLedger)
    : super(ShiftWorkflowState(ledger: initialLedger));

  void onMyWay() {
    if (state.dispatchStatus == DispatchStatus.confirmed &&
        state.ledger.status == LedgerStatus.escrowFunded) {
      emit(state.copyWith(dispatchStatus: DispatchStatus.onTheWay));
    }
  }

  void checkIn() {
    if (state.dispatchStatus == DispatchStatus.onTheWay &&
        state.ledger.status == LedgerStatus.escrowFunded) {
      emit(
        state.copyWith(
          ledger: _withStatus(state.ledger, LedgerStatus.shiftInProgress),
          dispatchStatus: DispatchStatus.checkedIn,
        ),
      );
    }
  }

  void completeShift() {
    if (state.dispatchStatus == DispatchStatus.checkedIn &&
        state.ledger.status == LedgerStatus.shiftInProgress) {
      emit(
        state.copyWith(
          ledger: _withStatus(state.ledger, LedgerStatus.pendingClientReview),
          dispatchStatus: DispatchStatus.completionSubmitted,
        ),
      );
    }
  }

  void dispute() {
    if (state.ledger.status != LedgerStatus.released &&
        state.ledger.status != LedgerStatus.disputed) {
      emit(
        state.copyWith(
          ledger: _withStatus(state.ledger, LedgerStatus.disputed),
        ),
      );
    }
  }

  LedgerEntry _withStatus(LedgerEntry entry, LedgerStatus status) =>
      LedgerEntry(
        transactionId: entry.transactionId,
        amountNpr: entry.amountNpr,
        status: status,
        updatedAt: DateTime.now(),
      );
}

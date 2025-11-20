// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library InstallmentLogic {
    struct InstallmentPlan {
        uint256 totalAmount;
        uint256 paidAmount;
        uint8 installmentCount;
        uint8 installmentsPaid;
        uint256 startTime;     // timestamp when first installment is due
        uint256 interval;      // seconds between installments (e.g., 30 days)
        bool active;
    }

    // NOTE: No events in library (callers should emit)

    /**
     * @notice Create a new installment plan
     * @param totalAmount Total amount to be paid
     * @param installments Number of installments
     * @param startTime Timestamp when first installment is due
     * @param interval Seconds between installments
     * @return plan The created installment plan
     */
    function createPlan(
        uint256 totalAmount,
        uint8 installments,
        uint256 startTime,
        uint256 interval
    ) internal pure returns (InstallmentPlan memory plan) {
        require(totalAmount > 0, "Installments: total=0");
        require(installments > 0, "Installments: count=0");
        require(interval > 0, "Installments: interval=0");
        require(startTime > 0, "Installments: start=0");

        plan = InstallmentPlan({
            totalAmount: totalAmount,
            paidAmount: 0,
            installmentCount: installments,
            installmentsPaid: 0,
            startTime: startTime,
            interval: interval,
            active: true
        });
    }

    /**
     * @notice Process an installment payment (full installment amounts only)
     * @param plan Storage reference to the installment plan
     * @param amount Amount being paid
     * @param currentTime Current block timestamp
     * @return remaining Amount remaining to be paid
     * @return isLateThisPayment Whether the just-paid installment was late
     */
    function payInstallment(
        InstallmentPlan storage plan,
        uint256 amount,
        uint256 currentTime
    ) internal returns (uint256 remaining, bool isLateThisPayment) {
        require(plan.active, "Installments: inactive");
        require(plan.installmentsPaid < plan.installmentCount, "Installments: complete");

        // Determine required installment amount.
        // For the last installment, allow the remainder to handle rounding.
        uint256 baseInstallment = plan.totalAmount / plan.installmentCount;
        uint8 nextCount = plan.installmentsPaid + 1;
        uint256 requiredAmount = nextCount == plan.installmentCount
            ? plan.totalAmount - plan.paidAmount
            : baseInstallment;

        require(amount == requiredAmount, "Installments: partial not allowed");

        // Determine lateness for this installment
        uint256 dueAt = plan.startTime + uint256(nextCount) * plan.interval;
        isLateThisPayment = currentTime > dueAt;

        plan.paidAmount += amount;
        plan.installmentsPaid = nextCount;

        remaining = plan.totalAmount - plan.paidAmount;
        if (remaining == 0) plan.active = false;
    }

    /**
     * @notice Get remaining amount
     * @param plan Storage reference to the installment plan
     * @return Remaining amount to be paid
     */
    function getRemaining(InstallmentPlan storage plan) internal view returns (uint256) {
        return plan.totalAmount - plan.paidAmount;
    }

    /**
     * @notice Check if plan is defaulted. Default occurs when at least one due installment
     *         has not been paid (i.e., number of installments that should be paid by now
     *         exceeds installmentsPaid), while the plan is still active.
     * @param plan Storage reference to the installment plan
     * @param currentTime Current block timestamp
     * @return defaulted Whether the plan is in default
     */
    function isDefaulted(InstallmentPlan storage plan, uint256 currentTime) internal view returns (bool defaulted) {
        if (!plan.active) return false;
        if (currentTime < plan.startTime) return false;

        // Number of installments that should have been paid by now
        uint256 elapsed = currentTime - plan.startTime;
        uint8 dueCount = uint8((elapsed / plan.interval) + 1);
        if (dueCount > plan.installmentCount) {
            dueCount = plan.installmentCount;
        }
        defaulted = dueCount > plan.installmentsPaid;
    }
}

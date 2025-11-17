// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library InstallmentLogic {
    struct InstallmentPlan {
        uint256 totalAmount;
        uint256 paidAmount;
        uint8 installmentCount;
        uint8 installmentsPaid;
        uint256 deadline;
        bool active;
    }

    event InstallmentPaid(uint256 indexed tokenId, uint256 amount, uint8 installmentsPaid);

    /**
     * @notice Create a new installment plan
     * @param totalAmount Total amount to be paid
     * @param installments Number of installments
     * @return plan The created installment plan
     */
    function createPlan(uint256 totalAmount, uint8 installments) internal pure returns (InstallmentPlan memory plan) {
        require(totalAmount > 0, "Invalid total amount");
        require(installments > 0, "Invalid installment count");
        
        plan = InstallmentPlan({
            totalAmount: totalAmount,
            paidAmount: 0,
            installmentCount: installments,
            installmentsPaid: 0,
            deadline: 0, // Set by caller if needed
            active: true
        });
    }

    /**
     * @notice Process an installment payment
     * @param plan Storage reference to the installment plan
     * @param amount Amount being paid
     * @param currentTime Current block timestamp
     * @return remaining Amount remaining to be paid
     * @return isLate Whether payment is late
     */
    function payInstallment(
        InstallmentPlan storage plan,
        uint256 amount,
        uint256 currentTime
    ) internal returns (uint256 remaining, bool isLate) {
        require(plan.active, "Plan not active");
        require(amount > 0, "Invalid payment amount");
        require(plan.paidAmount + amount <= plan.totalAmount, "Overpayment");

        plan.paidAmount += amount;
        plan.installmentsPaid += 1;

        remaining = plan.totalAmount - plan.paidAmount;
        isLate = plan.deadline > 0 && currentTime > plan.deadline;

        if (remaining == 0) {
            plan.active = false;
        }
    }

    /**
     * @notice Get the status of an installment plan
     * @param plan Storage reference to the installment plan
     * @param currentTime Current block timestamp
     * @return remaining Amount remaining to be paid
     * @return defaulted Whether the plan is in default
     */
    function getStatus(
        InstallmentPlan storage plan,
        uint256 currentTime
    ) internal view returns (uint256 remaining, bool defaulted) {
        remaining = plan.totalAmount - plan.paidAmount;
        defaulted = plan.active && plan.deadline > 0 && currentTime > plan.deadline && remaining > 0;
    }

    /**
     * @notice Get remaining amount
     * @param plan Memory reference to the installment plan
     * @return Remaining amount to be paid
     */
    function getRemaining(InstallmentPlan memory plan) internal pure returns (uint256) {
        return plan.totalAmount - plan.paidAmount;
    }

    /**
     * @notice Check if plan is defaulted
     * @param plan Storage reference to the installment plan
     * @param currentTime Current block timestamp
     * @return Whether the plan is in default
     */
    function isDefaulted(
        InstallmentPlan storage plan,
        uint256 currentTime
    ) internal view returns (bool) {
        return plan.active && 
               plan.deadline > 0 && 
               currentTime > plan.deadline && 
               plan.paidAmount < plan.totalAmount;
    }
}

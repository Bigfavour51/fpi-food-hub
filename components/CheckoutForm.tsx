import React from "react";

export default function CheckoutForm() {
  return (
    <div>
      <div className="space-y-4">
        <h3 className="text-lg font-semibold">Payment Details</h3>
        <div className="bg-gray-50 p-4 rounded-lg">
          <p className="text-sm text-gray-600 mb-2">Please make payment to:</p>
          <div className="space-y-2">
            <p className="font-medium">Account Name: FPIFOODHUB</p>
            <p className="font-medium">Account Number: 3022144523</p>
            <p className="font-medium">Bank: FirstBank</p>
          </div>
        </div>
      </div>
      <div className="space-y-2"> 
        {/* ...other form fields... */}
      </div>
    </div>
  );
} 
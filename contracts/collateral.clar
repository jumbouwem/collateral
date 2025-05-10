;; collateral - Decentralized Lending Protocol
;; A simple lending protocol where users can deposit STX and borrow against their collateral

;; Constants for error codes
(define-constant ERR-INSUFFICIENT-FUNDS u1)
(define-constant ERR-UNAUTHORIZED u2)
(define-constant ERR-NOT-LIQUIDATABLE u3)

;; Protocol parameters
(define-data-var min-collateral-ratio uint u150)
(define-data-var liquidation-threshold uint u130)
(define-data-var protocol-fee uint u1)
(define-data-var block-counter uint u0)

;; Maps for storing user data
(define-map deposits principal { amount: uint, timestamp: uint })
(define-map loans principal { amount: uint, collateral: uint, timestamp: uint })

;; Helper function to increment block counter (simulates block height)
(define-public (increment-block)
  (ok (var-set block-counter (+ (var-get block-counter) u1)))
)

;; Read-only functions
(define-read-only (get-deposit (user principal))
  (default-to { amount: u0, timestamp: u0 } (map-get? deposits user))
)

(define-read-only (get-loan (user principal))
  (default-to { amount: u0, collateral: u0, timestamp: u0 } (map-get? loans user))
)

(define-read-only (get-collateral-ratio (user principal))
  (let ((loan (get-loan user)))
    (if (is-eq (get amount loan) u0)
      u0
      (/ (* (get collateral loan) u100) (get amount loan))
    )
  )
)

;; Public functions
(define-public (deposit (amount uint))
  (let ((sender tx-sender)
        (current-deposit (get-deposit sender))
        (current-amount (get amount current-deposit))
        (new-amount (+ current-amount amount)))
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    
    ;; Update deposit record
    (map-set deposits 
      sender 
      { amount: new-amount, timestamp: (var-get block-counter) })
    
    (ok new-amount)
  )
)

(define-public (withdraw (amount uint))
  (let ((sender tx-sender)
        (current-deposit (get-deposit sender))
        (current-amount (get amount current-deposit)))
    
    ;; Check if user has enough funds
    (asserts! (<= amount current-amount) (err ERR-INSUFFICIENT-FUNDS))
    
    ;; Update deposit record
    (map-set deposits 
      sender 
      { amount: (- current-amount amount), timestamp: (var-get block-counter) })
    
    ;; Transfer STX to user
    (as-contract (try! (stx-transfer? amount (as-contract tx-sender) sender)))
    
    (ok (- current-amount amount))
  )
)

(define-public (borrow (amount uint))
  (let ((sender tx-sender)
        (current-deposit (get-deposit sender))
        (deposit-amount (get amount current-deposit))
        (current-loan (get-loan sender))
        (loan-amount (get amount current-loan))
        (collateral-amount (get collateral current-loan))
        (min-ratio (var-get min-collateral-ratio))
        (new-loan-amount (+ loan-amount amount))
        (new-collateral-amount (+ collateral-amount (* amount min-ratio))))
    
    ;; Check if user has enough deposit
    (asserts! (>= deposit-amount amount) (err ERR-INSUFFICIENT-FUNDS))
    
    ;; Update loan record
    (map-set loans 
      sender 
      { amount: new-loan-amount, 
        collateral: new-collateral-amount, 
        timestamp: (var-get block-counter) })
    
    ;; Transfer STX to user
    (as-contract (try! (stx-transfer? amount (as-contract tx-sender) sender)))
    
    (ok new-loan-amount)
  )
)

(define-public (repay (amount uint))
  (let ((sender tx-sender)
        (current-loan (get-loan sender))
        (loan-amount (get amount current-loan))
        (collateral-amount (get collateral current-loan))
        (min-ratio (var-get min-collateral-ratio))
        (new-loan-amount (- loan-amount amount))
        (new-collateral-amount (- collateral-amount (* amount min-ratio))))
    
    ;; Check if amount is valid
    (asserts! (<= amount loan-amount) (err ERR-INSUFFICIENT-FUNDS))
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    
    ;; Update loan record
    (map-set loans 
      sender 
      { amount: new-loan-amount, 
        collateral: new-collateral-amount, 
        timestamp: (var-get block-counter) })
    
    (ok new-loan-amount)
  )
)

(define-public (liquidate (user principal))
  (let ((sender tx-sender)
        (current-loan (get-loan user))
        (loan-amount (get amount current-loan))
        (collateral-amount (get collateral current-loan))
        (ratio (get-collateral-ratio user))
        (liq-threshold (var-get liquidation-threshold)))
    
    ;; Check if position is liquidatable
    (asserts! (< ratio liq-threshold) (err ERR-NOT-LIQUIDATABLE))
    
    ;; Transfer STX from liquidator to contract
    (try! (stx-transfer? loan-amount sender (as-contract tx-sender)))
    
    ;; Delete loan
    (map-delete loans user)
    
    ;; Transfer collateral to liquidator
    (as-contract (try! (stx-transfer? collateral-amount (as-contract tx-sender) sender)))
    
    (ok true)
  )
)
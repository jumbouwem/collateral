;; collateral - Decentralized Lending Protocol
;; A simple lending protocol where users can deposit STX and borrow against their collateral

(define-data-var min-collateral-ratio uint u150)
(define-data-var liquidation-threshold uint u130)
(define-data-var protocol-fee uint u1)
(define-data-var current-block uint u0)

;; Admin function to update the current block (simulating block height)
(define-public (update-block (new-block uint))
  (begin
    (var-set current-block new-block)
    (ok new-block)
  )
)

(define-map deposits
  { user: principal }
  { amount: uint, last-deposit-block: uint }
)

(define-map loans
  { user: principal }
  { amount: uint, collateral: uint, last-borrow-block: uint }
)

(define-read-only (get-deposit (user principal))
  (default-to { amount: u0, last-deposit-block: u0 } (map-get? deposits { user: user }))
)

(define-read-only (get-loan (user principal))
  (default-to { amount: u0, collateral: u0, last-borrow-block: u0 } (map-get? loans { user: user }))
)

(define-read-only (get-collateral-ratio (user principal))
  (let (
    (loan (get-loan user))
    (loan-amount (get amount loan))
    (collateral-amount (get collateral loan))
  )
    (if (is-eq loan-amount u0)
      u0
      (/ (* collateral-amount u100) loan-amount)
    )
  )
)

(define-public (deposit)
  (let (
    (sender tx-sender)
    (amount (stx-get-balance tx-sender))
    (current-deposit (get-deposit sender))
    (current-amount (get amount current-deposit))
    (new-amount (+ current-amount amount))
    (current-block-height (var-get current-block))
  )
    (begin
      (try! (stx-transfer? amount sender (as-contract tx-sender)))
      (map-set deposits
        { user: sender }
        { amount: new-amount, last-deposit-block: current-block-height }
      )
      (ok new-amount)
    )
  )
)

(define-public (withdraw (amount uint))
  (let (
    (sender tx-sender)
    (current-deposit (get-deposit sender))
    (current-amount (get amount current-deposit))
    (current-block-height (var-get current-block))
  )
    (asserts! (<= amount current-amount) (err u1))
    (let (
      (new-amount (- current-amount amount))
    )
      (map-set deposits
        { user: sender }
        { amount: new-amount, last-deposit-block: current-block-height }
      )
      (as-contract (stx-transfer? amount (as-contract tx-sender) sender))
      (ok new-amount)
    )
  )
)

(define-public (borrow (amount uint))
  (let (
    (sender tx-sender)
    (current-deposit (get-deposit sender))
    (deposit-amount (get amount current-deposit))
    (current-loan (get-loan sender))
    (loan-amount (get amount current-loan))
    (collateral-amount (get collateral current-loan))
    (min-ratio (var-get min-collateral-ratio))
    (current-block-height (var-get current-block))
  )
    (asserts! (>= deposit-amount amount) (err u1))
    (let (
      (new-loan-amount (+ loan-amount amount))
      (new-collateral-amount (+ collateral-amount (* amount min-ratio)))
    )
      (map-set loans
        { user: sender }
        { 
          amount: new-loan-amount, 
          collateral: new-collateral-amount, 
          last-borrow-block: current-block-height 
        }
      )
      (as-contract (stx-transfer? amount (as-contract tx-sender) sender))
      (ok new-loan-amount)
    )
  )
)

(define-public (repay (amount uint))
  (let (
    (sender tx-sender)
    (current-loan (get-loan sender))
    (loan-amount (get amount current-loan))
    (collateral-amount (get collateral current-loan))
    (current-block-height (var-get current-block))
  )
    (asserts! (<= amount loan-amount) (err u1))
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    (let (
      (new-loan-amount (- loan-amount amount))
      (new-collateral-amount (- collateral-amount (* amount (var-get min-collateral-ratio))))
    )
      (map-set loans
        { user: sender }
        { 
          amount: new-loan-amount, 
          collateral: new-collateral-amount, 
          last-borrow-block: current-block-height 
        }
      )
      (ok new-loan-amount)
    )
  )
)

(define-public (liquidate (user principal))
  (let (
    (sender tx-sender)
    (current-loan (get-loan user))
    (loan-amount (get amount current-loan))
    (collateral-amount (get collateral current-loan))
    (ratio (get-collateral-ratio user))
    (liquidation-threshold (var-get liquidation-threshold))
  )
    (asserts! (< ratio liquidation-threshold) (err u1))
    (try! (stx-transfer? loan-amount sender (as-contract tx-sender)))
    (map-delete loans { user: user })
    (as-contract (stx-transfer? collateral-amount (as-contract tx-sender) sender))
    (ok true)
  )
)
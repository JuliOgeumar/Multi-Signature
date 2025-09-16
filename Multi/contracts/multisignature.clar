;; Multi-Signature Wallet Contract with Enhanced Security and Optimization
;; Supports multiple owners, configurable thresholds, and transaction batching

;; =======================
;; Constants
;; =======================
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u600))
(define-constant ERR_NOT_OWNER (err u601))
(define-constant ERR_TRANSACTION_NOT_FOUND (err u602))
(define-constant ERR_ALREADY_CONFIRMED (err u603))
(define-constant ERR_ALREADY_EXECUTED (err u604))
(define-constant ERR_INSUFFICIENT_CONFIRMATIONS (err u605))
(define-constant ERR_INVALID_THRESHOLD (err u606))
(define-constant ERR_INVALID_OWNER (err u607))
(define-constant ERR_OWNER_EXISTS (err u608))
(define-constant ERR_OWNER_NOT_EXISTS (err u609))
(define-constant ERR_WALLET_LOCKED (err u610))
(define-constant ERR_INVALID_AMOUNT (err u611))
(define-constant ERR_EXECUTION_FAILED (err u612))
(define-constant ERR_TRANSACTION_EXPIRED (err u613))
(define-constant ERR_INVALID_NONCE (err u614))

;; Transaction types
(define-constant TX_TYPE_STX_TRANSFER u1)
(define-constant TX_TYPE_CONTRACT_CALL u2)
(define-constant TX_TYPE_ADD_OWNER u3)
(define-constant TX_TYPE_REMOVE_OWNER u4)
(define-constant TX_TYPE_CHANGE_THRESHOLD u5)
(define-constant TX_TYPE_BATCH_TRANSACTION u6)

;; Wallet configuration
(define-constant MAX_OWNERS u20)
(define-constant MIN_OWNERS u2)
(define-constant MAX_THRESHOLD u20)
(define-constant MIN_THRESHOLD u2)
(define-constant MAX_TRANSACTION_EXPIRY u52560) ;; ~1 year in blocks
(define-constant MIN_TRANSACTION_EXPIRY u144)   ;; ~1 day in blocks

;; =======================
;; Data Variables
;; =======================
(define-data-var wallet-locked bool false)
(define-data-var next-transaction-id uint u1)
(define-data-var confirmation-threshold uint u2)
(define-data-var total-owners uint u1)
(define-data-var nonce uint u0)
(define-data-var daily-limit uint u10000000) ;; 10 STX daily
(define-data-var daily-spent uint u0)
(define-data-var last-reset-day uint u0)
(define-data-var next-history-id uint u1)

;; =======================
;; Maps
;; =======================
(define-map wallet-owners principal bool)

(define-map owner-roles 
  principal 
  {
    role: uint, ;; 1=owner, 2=admin, 3=super-admin
    added-block: uint,
    added-by: principal,
    active: bool
  }
)

(define-map transactions
  uint
  {
    proposer: principal,
    tx-type: uint,
    recipient: (optional principal),
    amount: uint,
    contract-address: (optional principal),
    function-name: (optional (string-ascii 50)),
    function-args: (optional (buff 1024)),
    description: (string-ascii 200),
    confirmations: uint,
    executed: bool,
    created-block: uint,
    expiry-block: uint,
    execution-block: (optional uint),
    nonce: uint
  }
)

(define-map confirmations
  {transaction-id: uint, owner: principal}
  {
    confirmed: bool,
    confirmation-block: uint,
    signature: (optional (buff 65))
  }
)

(define-map batch-transactions
  uint
  {
    transaction-ids: (list 10 uint),
    batch-confirmations: uint,
    batch-executed: bool,
    created-block: uint
  }
)

(define-map transaction-history
  uint
  {
    transaction-id: uint,
    action: (string-ascii 20),
    actor: principal,
    block-height: uint,
    details: (optional (string-ascii 100))
  }
)

(define-map daily-spending
  uint ;; day index
  uint ;; amount spent
)

;; =======================
;; Private Helpers
;; =======================
(define-private (is-wallet-locked) (var-get wallet-locked))

(define-private (is-owner (user principal))
  (default-to false (map-get? wallet-owners user))
)

(define-private (get-owner-role (owner principal))
  (match (map-get? owner-roles owner)
    role-data (get role role-data)
    u0
  )
)

(define-private (has-sufficient-role (owner principal) (required-role uint))
  (>= (get-owner-role owner) required-role)
)

(define-private (reset-daily-spending-if-needed)
  (let (
    (current-day (/ stacks-block-height u144))
    (last-day (var-get last-reset-day))
  )
    (if (> current-day last-day)
      (begin
        (var-set daily-spent u0)
        (var-set last-reset-day current-day)
        true
      )
      true
    )
  )
)

(define-private (validate-transaction-params 
  (tx-type uint) 
  (amount uint) 
  (expiry-block uint)
  (description (string-ascii 200))
)
  (and
    (>= tx-type u1)
    (<= tx-type u6)
    (if (or (is-eq tx-type TX_TYPE_STX_TRANSFER) (is-eq tx-type TX_TYPE_BATCH_TRANSACTION))
      (> amount u0)
      true
    )
    (> expiry-block stacks-block-height)
    (<= (- expiry-block stacks-block-height) MAX_TRANSACTION_EXPIRY)
    (>= (- expiry-block stacks-block-height) MIN_TRANSACTION_EXPIRY)
    (> (len description) u0)
  )
)

(define-private (check-daily-limit (amount uint))
  (begin
    (reset-daily-spending-if-needed)
    (let ((current (var-get daily-spent)) (limit (var-get daily-limit)))
      (<= (+ current amount) limit)
    )
  )
)

(define-private (record-history (transaction-id uint) (action (string-ascii 20)) (details (optional (string-ascii 100))))
  (let ((history-id (var-get next-history-id)))
    (begin
      (map-set transaction-history history-id {
        transaction-id: transaction-id,
        action: action,
        actor: tx-sender,
        block-height: stacks-block-height,
        details: details
      })
      (var-set next-history-id (+ history-id u1))
    )
  )
)

;; =======================
;; Initialization
;; =======================
(define-public (initialize-wallet (owners (list 20 principal)) (threshold uint))
  (let ((owner-count (len owners)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (asserts! (>= owner-count MIN_OWNERS) ERR_INVALID_THRESHOLD)
    (asserts! (<= owner-count MAX_OWNERS) ERR_INVALID_THRESHOLD)
    (asserts! (>= threshold MIN_THRESHOLD) ERR_INVALID_THRESHOLD)
    (asserts! (<= threshold owner-count) ERR_INVALID_THRESHOLD)

    (var-set confirmation-threshold threshold)
    (var-set total-owners owner-count)

    ;; Fold over owners
    (let ((acc (fold add-owner-helper owners (ok true))))
      (match acc
        ok-val
          (begin
            (print {
              action: "initialize-wallet",
              owners: owners,
              threshold: threshold,
              owner-count: owner-count
            })
            (ok true))
        err-val (err err-val)
      )
    )
  )
)

(define-private (add-owner-helper (owner principal) (acc (response bool uint)))
  (match acc
    ok-val
      (begin
        (asserts! (is-none (map-get? wallet-owners owner)) ERR_OWNER_EXISTS)
        (map-set wallet-owners owner true)
        (map-set owner-roles owner {
          role: u1,
          added-block: stacks-block-height,
          added-by: CONTRACT_OWNER,
          active: true
        })
        (ok true)
      )
    err-val (err err-val)
  )
)


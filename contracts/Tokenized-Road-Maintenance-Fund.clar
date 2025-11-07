(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-VOTING-CLOSED (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-PROPOSAL-NOT-APPROVED (err u106))
(define-constant ERR-ALREADY-EXECUTED (err u107))
(define-constant ERR-NOT-DAO-MEMBER (err u108))

(define-constant ERR-EMERGENCY-NOT-FOUND (err u110))
(define-constant ERR-EMERGENCY-EXPIRED (err u111))
(define-constant ERR-ALREADY-CONFIRMED (err u112))
(define-constant ERR-INSUFFICIENT-CONFIRMATIONS (err u113))
(define-constant ERR-EMERGENCY-LIMIT-EXCEEDED (err u114))

(define-constant ERR-NO-REWARDS-AVAILABLE (err u120))
(define-constant ERR-MILESTONE-NOT-REACHED (err u121))
(define-constant ERR-REWARDS-ALREADY-CLAIMED (err u122))

(define-constant ERR-CANNOT-DELEGATE-TO-SELF (err u130))
(define-constant ERR-DELEGATE-NOT-DAO-MEMBER (err u131))
(define-constant ERR-NO-ACTIVE-DELEGATION (err u132))

(define-constant ERR-AMENDMENT-WINDOW-CLOSED (err u140))
(define-constant ERR-NOT-PROPOSER (err u141))
(define-constant ERR-AMENDMENT-LIMIT-REACHED (err u142))

(define-data-var current-milestone uint u0)
(define-data-var reward-pool uint u0)
(define-data-var milestone-threshold uint u10000000)

(define-data-var emergency-count uint u0)

(define-data-var fund-balance uint u0)
(define-data-var proposal-count uint u0)
(define-data-var dao-member-count uint u0)

(define-map contributors principal uint)
(define-map dao-members principal bool)
(define-map proposals  
  uint 
  {
    proposer: principal,
    recipient: principal,
    amount: uint,
    description: (string-ascii 500),
    votes-for: uint,
    votes-against: uint,
    voting-deadline: uint,
    executed: bool,
    amendment-count: uint
  }
)
(define-map votes { proposal-id: uint, voter: principal } bool)

(define-public (contribute (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set fund-balance (+ (var-get fund-balance) amount))
    (map-set contributors tx-sender 
      (+ (default-to u0 (map-get? contributors tx-sender)) amount))
    (ok true)
  )
)

(define-public (join-dao)
  (begin
    (asserts! (> (default-to u0 (map-get? contributors tx-sender)) u1000000) ERR-UNAUTHORIZED)
    (asserts! (is-none (map-get? dao-members tx-sender)) ERR-UNAUTHORIZED)
    (map-set dao-members tx-sender true)
    (var-set dao-member-count (+ (var-get dao-member-count) u1))
    (ok true)
  )
)

(define-public (create-proposal (recipient principal) (amount uint) (description (string-ascii 500)))
  (let 
    (
      (proposal-id (+ (var-get proposal-count) u1))
      (deadline (+ stacks-block-height u1440))
    )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (var-get fund-balance)) ERR-INSUFFICIENT-FUNDS)
    (map-set proposals proposal-id {
      proposer: tx-sender,
      recipient: recipient,
      amount: amount,
      description: description,
      votes-for: u0,
      votes-against: u0,
      voting-deadline: deadline,
      executed: false,
      amendment-count: u0
    })
    (var-set proposal-count proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (vote-for bool))
  (let 
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (vote-key { proposal-id: proposal-id, voter: tx-sender })
      (voter-power (get-voting-power tx-sender))
    )
    (asserts! (default-to false (map-get? dao-members tx-sender)) ERR-NOT-DAO-MEMBER)
    (asserts! (is-none (map-get? votes vote-key)) ERR-ALREADY-VOTED)
    (asserts! (< stacks-block-height (get voting-deadline proposal)) ERR-VOTING-CLOSED)
    
    (map-set votes vote-key true)
    (if vote-for
      (map-set proposals proposal-id (merge proposal { votes-for: (+ (get votes-for proposal) voter-power) }))
      (map-set proposals proposal-id (merge proposal { votes-against: (+ (get votes-against proposal) voter-power) }))
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let 
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
      (quorum (/ (var-get dao-member-count) u2))
    )
    (asserts! (>= stacks-block-height (get voting-deadline proposal)) ERR-VOTING-CLOSED)
    (asserts! (not (get executed proposal)) ERR-ALREADY-EXECUTED)
    (asserts! (>= total-votes quorum) ERR-PROPOSAL-NOT-APPROVED)
    (asserts! (> (get votes-for proposal) (get votes-against proposal)) ERR-PROPOSAL-NOT-APPROVED)
    (asserts! (>= (var-get fund-balance) (get amount proposal)) ERR-INSUFFICIENT-FUNDS)
    
    (try! (as-contract (stx-transfer? (get amount proposal) tx-sender (get recipient proposal))))
    (var-set fund-balance (- (var-get fund-balance) (get amount proposal)))
    (map-set proposals proposal-id (merge proposal { executed: true }))
    (ok true)
  )
)

(define-read-only (get-fund-balance)
  (var-get fund-balance)
)

(define-read-only (get-contributor-balance (contributor principal))
  (default-to u0 (map-get? contributors contributor))
)

(define-read-only (is-dao-member (member principal))
  (default-to false (map-get? dao-members member))
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-proposal-count)
  (var-get proposal-count)
)

(define-read-only (get-dao-member-count)
  (var-get dao-member-count)
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? votes { proposal-id: proposal-id, voter: voter }))
)



(define-read-only (is-proposal-approved (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal 
    (let 
      (
        (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
        (quorum (/ (var-get dao-member-count) u2))
      )
      (and 
        (>= total-votes quorum)
        (> (get votes-for proposal) (get votes-against proposal))
      )
    )
    false
  )
)

(define-read-only (get-contract-info)
  {
    fund-balance: (var-get fund-balance),
    proposal-count: (var-get proposal-count),
    dao-member-count: (var-get dao-member-count),
    contract-owner: CONTRACT-OWNER
  }
)

(map-set dao-members CONTRACT-OWNER true)
(var-set dao-member-count u1)


(define-map emergency-withdrawals
  uint
  {
    initiator: principal,
    recipient: principal,
    amount: uint,
    reason: (string-ascii 200),
    confirmations: uint,
    deadline: uint,
    executed: bool
  }
)

(define-map emergency-confirmations { emergency-id: uint, confirmer: principal } bool)

(define-public (initiate-emergency-withdrawal (recipient principal) (amount uint) (reason (string-ascii 200)))
  (let 
    (
      (emergency-id (+ (var-get emergency-count) u1))
      (max-emergency-amount (/ (var-get fund-balance) u10))
      (deadline (+ stacks-block-height u144))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount max-emergency-amount) ERR-EMERGENCY-LIMIT-EXCEEDED)
    (asserts! (<= amount (var-get fund-balance)) ERR-INSUFFICIENT-FUNDS)
    
    (map-set emergency-withdrawals emergency-id {
      initiator: tx-sender,
      recipient: recipient,
      amount: amount,
      reason: reason,
      confirmations: u0,
      deadline: deadline,
      executed: false
    })
    (var-set emergency-count emergency-id)
    (ok emergency-id)
  )
)

(define-public (confirm-emergency (emergency-id uint))
  (let 
    (
      (emergency (unwrap! (map-get? emergency-withdrawals emergency-id) ERR-EMERGENCY-NOT-FOUND))
      (confirmation-key { emergency-id: emergency-id, confirmer: tx-sender })
    )
    (asserts! (default-to false (map-get? dao-members tx-sender)) ERR-NOT-DAO-MEMBER)
    (asserts! (< stacks-block-height (get deadline emergency)) ERR-EMERGENCY-EXPIRED)
    (asserts! (is-none (map-get? emergency-confirmations confirmation-key)) ERR-ALREADY-CONFIRMED)
    
    (map-set emergency-confirmations confirmation-key true)
    (map-set emergency-withdrawals emergency-id 
      (merge emergency { confirmations: (+ (get confirmations emergency) u1) }))
    (ok true)
  )
)

(define-public (execute-emergency (emergency-id uint))
  (let 
    (
      (emergency (unwrap! (map-get? emergency-withdrawals emergency-id) ERR-EMERGENCY-NOT-FOUND))
      (required-confirmations (/ (var-get dao-member-count) u3))
    )
    (asserts! (< stacks-block-height (get deadline emergency)) ERR-EMERGENCY-EXPIRED)
    (asserts! (not (get executed emergency)) ERR-ALREADY-EXECUTED)
    (asserts! (>= (get confirmations emergency) required-confirmations) ERR-INSUFFICIENT-CONFIRMATIONS)
    (asserts! (>= (var-get fund-balance) (get amount emergency)) ERR-INSUFFICIENT-FUNDS)
    
    (try! (as-contract (stx-transfer? (get amount emergency) tx-sender (get recipient emergency))))
    (var-set fund-balance (- (var-get fund-balance) (get amount emergency)))
    (map-set emergency-withdrawals emergency-id (merge emergency { executed: true }))
    (ok true)
  )
)

(define-read-only (get-emergency (emergency-id uint))
  (map-get? emergency-withdrawals emergency-id)
)

(define-read-only (get-emergency-count)
  (var-get emergency-count)
)

(define-read-only (has-confirmed-emergency (emergency-id uint) (confirmer principal))
  (is-some (map-get? emergency-confirmations { emergency-id: emergency-id, confirmer: confirmer }))
)


(define-map milestone-rewards
  { milestone: uint, contributor: principal }
  { amount: uint, claimed: bool }
)

(define-map contributor-milestone-eligibility principal uint)

(define-public (check-and-distribute-milestone)
  (let
    (
      (current-balance (var-get fund-balance))
      (current-milestone-num (var-get current-milestone))
      (threshold (* (var-get milestone-threshold) (+ current-milestone-num u1)))
    )
    (if (>= current-balance threshold)
      (begin
        (var-set current-milestone (+ current-milestone-num u1))
        (var-set reward-pool (+ (var-get reward-pool) (/ threshold u20)))
        (ok (var-get current-milestone))
      )
      (ok u0)
    )
  )
)

(define-public (calculate-contributor-reward (contributor principal))
  (let
    (
      (contribution (default-to u0 (map-get? contributors contributor)))
      (total-fund (var-get fund-balance))
      (available-rewards (var-get reward-pool))
      (milestone-num (var-get current-milestone))
      (eligible-milestone (default-to u0 (map-get? contributor-milestone-eligibility contributor)))
    )
    (if (and (> milestone-num eligible-milestone) (> contribution u0) (> available-rewards u0))
      (let
        (
          (reward-amount (/ (* available-rewards contribution) total-fund))
        )
        (map-set milestone-rewards 
          { milestone: milestone-num, contributor: contributor }
          { amount: reward-amount, claimed: false }
        )
        (map-set contributor-milestone-eligibility contributor milestone-num)
        (ok reward-amount)
      )
      (ok u0)
    )
  )
)

(define-public (claim-milestone-reward (milestone uint))
  (let
    (
      (reward-key { milestone: milestone, contributor: tx-sender })
      (reward-data (unwrap! (map-get? milestone-rewards reward-key) ERR-NO-REWARDS-AVAILABLE))
    )
    (asserts! (not (get claimed reward-data)) ERR-REWARDS-ALREADY-CLAIMED)
    (asserts! (<= milestone (var-get current-milestone)) ERR-MILESTONE-NOT-REACHED)
    (asserts! (>= (var-get reward-pool) (get amount reward-data)) ERR-INSUFFICIENT-FUNDS)
    
    (try! (as-contract (stx-transfer? (get amount reward-data) tx-sender tx-sender)))
    (var-set reward-pool (- (var-get reward-pool) (get amount reward-data)))
    (map-set milestone-rewards reward-key (merge reward-data { claimed: true }))
    (ok (get amount reward-data))
  )
)

(define-read-only (get-milestone-status)
  {
    current-milestone: (var-get current-milestone),
    reward-pool: (var-get reward-pool),
    next-threshold: (* (var-get milestone-threshold) (+ (var-get current-milestone) u1))
  }
)

(define-read-only (get-contributor-reward-info (contributor principal) (milestone uint))
  (map-get? milestone-rewards { milestone: milestone, contributor: contributor })
)

(define-map delegations principal principal)
(define-map delegation-power principal uint)

(define-public (delegate-voting-power (delegate principal))
  (begin
    (asserts! (default-to false (map-get? dao-members tx-sender)) ERR-NOT-DAO-MEMBER)
    (asserts! (default-to false (map-get? dao-members delegate)) ERR-DELEGATE-NOT-DAO-MEMBER)
    (asserts! (not (is-eq tx-sender delegate)) ERR-CANNOT-DELEGATE-TO-SELF)
    
    (match (map-get? delegations tx-sender)
      old-delegate 
      (map-set delegation-power old-delegate 
        (- (default-to u1 (map-get? delegation-power old-delegate)) u1))
      true
    )
    
    (map-set delegations tx-sender delegate)
    (map-set delegation-power delegate 
      (+ (default-to u1 (map-get? delegation-power delegate)) u1))
    (ok true)
  )
)

(define-public (revoke-delegation)
  (let
    (
      (current-delegate (unwrap! (map-get? delegations tx-sender) ERR-NO-ACTIVE-DELEGATION))
    )
    (map-delete delegations tx-sender)
    (map-set delegation-power current-delegate 
      (- (default-to u1 (map-get? delegation-power current-delegate)) u1))
    (ok true)
  )
)

(define-read-only (get-voting-power (member principal))
  (if (default-to false (map-get? dao-members member))
    (default-to u1 (map-get? delegation-power member))
    u0
  )
)

(define-read-only (get-delegated-power (member principal))
  {
    base-power: (if (default-to false (map-get? dao-members member)) u1 u0),
    delegated-power: (default-to u0 (map-get? delegation-power member)),
    total-power: (get-voting-power member),
    current-delegate: (map-get? delegations member)
  }
)

(define-map vote-versions { proposal-id: uint, voter: principal } uint)

(define-public (amend-proposal (proposal-id uint) (new-recipient (optional principal)) (new-amount (optional uint)) (new-description (optional (string-ascii 500))))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (amendment-window (- (get voting-deadline proposal) u720))
      (current-amendments (get amendment-count proposal))
      (updated-recipient (default-to (get recipient proposal) new-recipient))
      (updated-amount (default-to (get amount proposal) new-amount))
      (updated-description (default-to (get description proposal) new-description))
    )
    (asserts! (is-eq tx-sender (get proposer proposal)) ERR-NOT-PROPOSER)
    (asserts! (not (get executed proposal)) ERR-ALREADY-EXECUTED)
    (asserts! (< stacks-block-height amendment-window) ERR-AMENDMENT-WINDOW-CLOSED)
    (asserts! (< current-amendments u3) ERR-AMENDMENT-LIMIT-REACHED)
    (asserts! (> updated-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= updated-amount (var-get fund-balance)) ERR-INSUFFICIENT-FUNDS)
    
    (map-set proposals proposal-id (merge proposal {
      recipient: updated-recipient,
      amount: updated-amount,
      description: updated-description,
      votes-for: u0,
      votes-against: u0,
      amendment-count: (+ current-amendments u1)
    }))
    (ok true)
  )
)

(define-read-only (can-amend-proposal (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal
    (let
      (
        (amendment-window (- (get voting-deadline proposal) u720))
        (current-amendments (get amendment-count proposal))
      )
      {
        can-amend: (and 
          (< stacks-block-height amendment-window)
          (not (get executed proposal))
          (< current-amendments u3)
        ),
        remaining-amendments: (- u3 current-amendments),
        amendment-deadline: amendment-window
      }
    )
    { can-amend: false, remaining-amendments: u0, amendment-deadline: u0 }
  )
)

(define-read-only (get-amendment-info (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal
    {
      amendment-count: (get amendment-count proposal),
      max-amendments: u3,
      amendments-remaining: (- u3 (get amendment-count proposal))
    }
    { amendment-count: u0, max-amendments: u3, amendments-remaining: u0 }
  )
)
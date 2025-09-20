;; Esports Tournament Management Smart Contract
;; Manages tournament creation, registration, matches, and prize distribution

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-state (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-already-exists (err u105))
(define-constant err-tournament-full (err u106))
(define-constant err-invalid-params (err u107))
(define-constant max-entry-fee u1000000) ;; 1M microSTX max
(define-constant max-round u100)
(define-constant max-prize-pool u100000000) ;; 100M microSTX max

;; Data Variables
(define-data-var next-tournament-id uint u1)
(define-data-var next-match-id uint u1)
(define-data-var platform-fee uint u50) ;; 5% fee

;; Tournament status enum
(define-constant status-open u0)
(define-constant status-ongoing u1)
(define-constant status-completed u2)
(define-constant status-cancelled u3)

;; Data Maps
(define-map tournaments uint {
    name: (string-ascii 100),
    organizer: principal,
    entry-fee: uint,
    max-participants: uint,
    current-participants: uint,
    prize-pool: uint,
    start-time: uint,
    status: uint,
    winner: (optional principal)
})

(define-map tournament-participants {tournament-id: uint, participant: principal} {
    registered-at: uint,
    eliminated: bool
})

(define-map matches uint {
    tournament-id: uint,
    player1: principal,
    player2: principal,
    winner: (optional principal),
    round: uint,
    completed: bool,
    match-time: uint
})

(define-map user-stats principal {
    tournaments-won: uint,
    tournaments-participated: uint,
    total-winnings: uint
})

;; Read-only functions
(define-read-only (get-tournament (tournament-id uint))
    (map-get? tournaments tournament-id))

(define-read-only (get-match (match-id uint))
    (map-get? matches match-id))

(define-read-only (get-user-stats (user principal))
    (default-to 
        {tournaments-won: u0, tournaments-participated: u0, total-winnings: u0}
        (map-get? user-stats user)))

(define-read-only (is-participant (tournament-id uint) (user principal))
    (is-some (map-get? tournament-participants {tournament-id: tournament-id, participant: user})))

(define-read-only (get-platform-fee)
    (var-get platform-fee))

;; Private functions
(define-private (update-user-stats (user principal) (won bool) (winnings uint))
    (let ((current-stats (get-user-stats user)))
        (map-set user-stats user {
            tournaments-won: (if won (+ (get tournaments-won current-stats) u1) (get tournaments-won current-stats)),
            tournaments-participated: (+ (get tournaments-participated current-stats) u1),
            total-winnings: (+ (get total-winnings current-stats) winnings)
        })))

(define-private (calculate-prize-distribution (prize-pool uint))
    (let ((validated-pool (if (<= prize-pool max-prize-pool) prize-pool u0)))
        (if (> validated-pool u0)
            {
                winner: (/ (* validated-pool u70) u100),
                runner-up: (/ (* validated-pool u20) u100),
                platform: (/ (* validated-pool (var-get platform-fee)) u100)
            }
            {winner: u0, runner-up: u0, platform: u0})))

(define-private (validate-entry-fee (fee uint))
    (and (<= fee max-entry-fee) (>= fee u0)))

(define-private (validate-round (round uint))
    (and (<= round max-round) (> round u0)))

(define-private (validate-prize-pool (pool uint))
    (<= pool max-prize-pool))

;; Public functions
(define-public (create-tournament 
    (name (string-ascii 100))
    (entry-fee uint)
    (max-participants uint)
    (start-time uint))
    (let ((tournament-id (var-get next-tournament-id))
          (validated-fee (if (validate-entry-fee entry-fee) entry-fee u0)))
        (asserts! (> max-participants u1) err-invalid-params)
        (asserts! (> start-time block-height) err-invalid-params)
        (asserts! (> (len name) u0) err-invalid-params)
        (asserts! (validate-entry-fee entry-fee) err-invalid-params)
        
        (map-set tournaments tournament-id {
            name: name,
            organizer: tx-sender,
            entry-fee: validated-fee,
            max-participants: max-participants,
            current-participants: u0,
            prize-pool: u0,
            start-time: start-time,
            status: status-open,
            winner: none
        })
        
        (var-set next-tournament-id (+ tournament-id u1))
        (ok tournament-id)))

(define-public (register-for-tournament (tournament-id uint))
    (let ((tournament (unwrap! (get-tournament tournament-id) err-not-found))
          (validated-fee (get entry-fee tournament)))
        (asserts! (is-eq (get status tournament) status-open) err-invalid-state)
        (asserts! (< (get current-participants tournament) (get max-participants tournament)) err-tournament-full)
        (asserts! (not (is-participant tournament-id tx-sender)) err-already-exists)
        (asserts! (>= (stx-get-balance tx-sender) validated-fee) err-insufficient-funds)
        
        ;; Transfer entry fee
        (if (> validated-fee u0)
            (try! (stx-transfer? validated-fee tx-sender (as-contract tx-sender)))
            true)
        
        ;; Register participant
        (map-set tournament-participants 
            {tournament-id: tournament-id, participant: tx-sender}
            {registered-at: block-height, eliminated: false})
        
        ;; Update tournament
        (map-set tournaments tournament-id 
            (merge tournament {
                current-participants: (+ (get current-participants tournament) u1),
                prize-pool: (+ (get prize-pool tournament) validated-fee)
            }))
        
        (ok true)))

(define-public (start-tournament (tournament-id uint))
    (let ((tournament (unwrap! (get-tournament tournament-id) err-not-found)))
        (asserts! (is-eq tx-sender (get organizer tournament)) err-unauthorized)
        (asserts! (is-eq (get status tournament) status-open) err-invalid-state)
        (asserts! (>= block-height (get start-time tournament)) err-invalid-state)
        (asserts! (> (get current-participants tournament) u1) err-invalid-params)
        
        (map-set tournaments tournament-id 
            (merge tournament {status: status-ongoing}))
        (ok true)))

(define-public (create-match 
    (tournament-id uint)
    (player1 principal)
    (player2 principal)
    (round uint))
    (let ((tournament (unwrap! (get-tournament tournament-id) err-not-found))
          (match-id (var-get next-match-id))
          (validated-round (if (validate-round round) round u1)))
        (asserts! (is-eq tx-sender (get organizer tournament)) err-unauthorized)
        (asserts! (is-eq (get status tournament) status-ongoing) err-invalid-state)
        (asserts! (is-participant tournament-id player1) err-not-found)
        (asserts! (is-participant tournament-id player2) err-not-found)
        (asserts! (validate-round round) err-invalid-params)
        
        (map-set matches match-id {
            tournament-id: tournament-id,
            player1: player1,
            player2: player2,
            winner: none,
            round: validated-round,
            completed: false,
            match-time: block-height
        })
        
        (var-set next-match-id (+ match-id u1))
        (ok match-id)))

(define-public (report-match-result (match-id uint) (winner principal))
    (let ((match-data (unwrap! (get-match match-id) err-not-found))
          (tournament (unwrap! (get-tournament (get tournament-id match-data)) err-not-found)))
        (asserts! (is-eq tx-sender (get organizer tournament)) err-unauthorized)
        (asserts! (not (get completed match-data)) err-invalid-state)
        (asserts! (or (is-eq winner (get player1 match-data)) 
                      (is-eq winner (get player2 match-data))) err-invalid-params)
        
        ;; Update match
        (map-set matches match-id 
            (merge match-data {winner: (some winner), completed: true}))
        
        ;; Eliminate loser
        (let ((loser (if (is-eq winner (get player1 match-data)) 
                         (get player2 match-data) 
                         (get player1 match-data))))
            (map-set tournament-participants 
                {tournament-id: (get tournament-id match-data), participant: loser}
                {registered-at: u0, eliminated: true}))
        
        (ok true)))

(define-public (finalize-tournament (tournament-id uint) (winner principal))
    (let ((tournament (unwrap! (get-tournament tournament-id) err-not-found))
          (validated-pool (get prize-pool tournament))
          (prize-dist (calculate-prize-distribution validated-pool)))
        (asserts! (is-eq tx-sender (get organizer tournament)) err-unauthorized)
        (asserts! (is-eq (get status tournament) status-ongoing) err-invalid-state)
        (asserts! (is-participant tournament-id winner) err-not-found)
        (asserts! (validate-prize-pool validated-pool) err-invalid-params)
        
        ;; Update tournament
        (map-set tournaments tournament-id 
            (merge tournament {status: status-completed, winner: (some winner)}))
        
        ;; Distribute prizes
        (let ((winner-prize (get winner prize-dist)))
            (if (> winner-prize u0)
                (try! (as-contract (stx-transfer? winner-prize tx-sender winner)))
                true))
        
        ;; Update winner stats
        (update-user-stats winner true (get winner prize-dist))
        
        (ok true)))

(define-public (cancel-tournament (tournament-id uint))
    (let ((tournament (unwrap! (get-tournament tournament-id) err-not-found)))
        (asserts! (is-eq tx-sender (get organizer tournament)) err-unauthorized)
        (asserts! (not (is-eq (get status tournament) status-completed)) err-invalid-state)
        
        (map-set tournaments tournament-id 
            (merge tournament {status: status-cancelled}))
        (ok true)))

(define-public (withdraw-refund (tournament-id uint))
    (let ((tournament (unwrap! (get-tournament tournament-id) err-not-found))
          (refund-amount (get entry-fee tournament)))
        (asserts! (is-eq (get status tournament) status-cancelled) err-invalid-state)
        (asserts! (is-participant tournament-id tx-sender) err-unauthorized)
        (asserts! (> refund-amount u0) err-invalid-params)
        
        (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
        (ok true)))

(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee u100) err-invalid-params)
        (var-set platform-fee new-fee)
        (ok true)))

(define-public (emergency-withdraw (tournament-id uint))
    (let ((tournament (unwrap! (get-tournament tournament-id) err-not-found)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> (get prize-pool tournament) u0) err-invalid-params)
        
        (try! (as-contract (stx-transfer? (get prize-pool tournament) tx-sender contract-owner)))
        (ok true)))
extensions [table]

globals [immigration districts file-name-pop file-name-entropy file-name-prices file-name-income file-name-world file-name-allured version save-directory
  allured-districts firstallure declining neighbourhoods-table  ;; compiles a list of neighbouhoods at start for quick lookup when running
  disp-freq ;; how many ticks between updates of entropy graph
  disp? ;; whether entropy graph should be displayed this tick
  city-allure profit-n profit-s profit-ne profit-nw profit-c profit-sw profit-se profit-e profit-w
  av-income sd-income sd-income+ sd-income- occupation-rate gentrified-districts downfiltered-districts
  recolonisation degentrification recreation regentrification
  housing-waiting-list file-name-donut totalcondition file-name-repair medianprices median-income
]
breed [citizens citizen]
breed [people person]
links-own [time]
turtles-own [mobility-propensity months-here birthday culture income dissonance  place-changes time-in-a-slum]
patches-own [ref condition price centre? dist local-dist premium price-gap months-empty neighbourhood allure social? last-renovated]

to setup
  clear-all
  set version "0.2.17"
  set save-directory "../results/"
  set disp-freq 5
  set disp? false
  set firstallure 0
  set allured-districts table:make
  set gentrified-districts table:make
  set downfiltered-districts table:make
  set housing-waiting-list table:make
  set declining []
  set recolonisation []
  set degentrification []
  set regentrification []
  set recreation []
  set totalcondition []
  set medianprices []
  set median-income []
  set city-allure n-values traits ["x"]
  ifelse enable-culture [
    set Mixing? true
    set PULL? true
    set PUSH? true
    set strong-neighbourhood? true
  ]
  [
    set Mixing? false
    set PULL? false
    set PUSH? False
    set strong-neighbourhood? false
    ]
  if Record? [movie-cancel]
  ;set allured-districts []
  ask patches
    [ set pcolor white
      set social? false
      set condition random-float 1
      create-price
      set months-empty 0
      set allure []
      set-neighbourhood
      ;set centreness 0.00001
     ; if areamax? [set premium 1]
    ]
  set districts remove-duplicates [neighbourhood] of patches

  set neighbourhoods-table table:from-list map [list ? (patches with [neighbourhood = ?])] districts

  set-centres-and-distances
  ask patches [
    color-patches
    ;set-last-renovated
    ]
    create-people N-Agents * 10 [
      ;set size 0.01
      set size 0.5
      set birthday 0
      create-culture
      reset-mobility-propensity
      set hidden? true
    ]
    set-default-shape turtles "circle"
    create-economic-status
    allocate-agents
  reset-ticks
  if Record? [movie-start "/home/stefano/gentaxelling.mov"]
  if write-csv? or paperstuff? [prepare-data-save]
end

to create-price   ;; Price dependant on condition + location. We need to look into this.
  set price condition + 0.1
  if neighbourhood = "cbd" [set price price * 1.60]
  if price > 1 [set price 1]
end

to set-centres-and-distances
  foreach districts [
    let x (([pxcor] of max-one-of patches with [neighbourhood = ?] [pxcor] - [pxcor] of min-one-of patches with [neighbourhood = ?] [pxcor]) / 2) + [pxcor] of min-one-of patches with [neighbourhood = ?] [pxcor]
    let y (([pycor] of max-one-of patches with [neighbourhood = ?] [pycor] - [pycor] of min-one-of patches with [neighbourhood = ?] [pycor]) / 2) + [pycor] of min-one-of patches with [neighbourhood = ?] [pycor]
    ask patch x y [
      if neighbourhood = ? [
        set centre? true
        set pcolor blue
      ]
    ]
  ]
  ask patches [
    let centre min-one-of patches with [centre? = true] [distance myself]  ;; policentric city
    set local-dist distance centre
    set dist distancexy 0 0
    if kind = "policentric" [set dist local-dist]
    if kind = "no centres"  [set dist 1]
  ]
end

to set-neighbourhood
  if pxcor >= -10 and pxcor < -2 and pycor > 2 and pycor <= 10 [set neighbourhood "nw"]
  if pxcor <= 10 and pxcor > 2 and pycor > 2 and pycor <= 10 [set neighbourhood "ne"]
  if pxcor >= -2 and pxcor <= 2 and pycor >= -2 and pycor <= 2 [
    set neighbourhood "c"
    ;set plabel "CBD"
  ]
  if pxcor >= -10 and pxcor < -2 and pycor < -2 and pycor >= -10 [set neighbourhood "sw"]
  if pxcor >= -10 and pxcor <= -3 and pycor > -4 and pycor < 4 [set neighbourhood "w"]
  if pxcor <= 10 and pxcor > 2 and pycor < -2 and pycor >= -10 [set neighbourhood "se"]
  if pxcor <= 10 and pxcor >= 3 and pycor > -4 and pycor < 4 [set neighbourhood "e"]
  if pxcor >= -3 and pxcor <= 3 and pycor < -2 and pycor >= -10 [set neighbourhood "s"]
  if pxcor >= -3 and pxcor <= 3 and pycor > 2 and pycor <= 10 [set neighbourhood "n"]
end


to create-culture
  set culture n-values traits [random values]
end

to create-economic-status
  ask people [set income random-float 0.90]
  if random-income? = false [create-skewed-economic-status]
end

to allocate-agents
  while [count citizens < N-Agents] [
    ask one-of people [
      if any? patches with [count citizens-here = 0 and price <= [income] of myself]
       [
         move-to one-of patches with [count citizens-here = 0 and price <= [income] of myself ]
         set breed citizens
         set hidden? false
         color-agent
         ]
       set months-here 0
    ]
  ]
end

to reset-mobility-propensity
  set mobility-propensity (random-float prob-move) + 0.01
end

to create-skewed-economic-status
  ;;  adjust one up and one down each time since this method changes the mean - Not SURE this is an improvement!
  let thresh 0.05
  let chng 0.8
  let chng-abs 0
  let med 0
  if init-gini - gini people > thresh [
    while [init-gini - gini people > thresh] [
      set med mean ([income] of people)
      ask one-of people with [income > med] [
        set chng-abs chng * (income - med)
        set income income + chng-abs
      ]
      ask one-of people with [income < med] [
        set income max list 0 income - chng-abs
      ]
    ;  show (word med " " gini people)
    ]
  ]
  if gini people - init-gini > thresh
  [ while [gini people - init-gini > thresh] [
      set med mean ([income] of people)
      ask one-of people with [income < med] [
        set chng-abs chng * (med - income)
        set income income + chng-abs
      ]
      ask one-of people with [income > med] [set income max list 0 income - chng-abs]
   ;   show (word med " " gini people)
    ]
  ]
  ask turtles with [income > 1][set income 1]
end

to-report gini [group]
  let sorted-wealths sort [income] of group
  let total-wealth sum sorted-wealths
  let wealth-sum-so-far 0
  let index 0
  let gini-index-reserve 0
  let lorenz-points []
  repeat count group [
    set wealth-sum-so-far (wealth-sum-so-far + item index sorted-wealths)
    set lorenz-points lput ((wealth-sum-so-far / total-wealth) * 100) lorenz-points
    set index (index + 1)
    set gini-index-reserve gini-index-reserve + (index / count group) - (wealth-sum-so-far / total-wealth)
  ]
  report (gini-index-reserve / count group) / 0.5
end

to-report occupancy [place]
  let total place
  if not is-patch-set? place [set total patches with [neighbourhood = place]]
  let occupied count total with [count citizens-here > 0]
  report occupied / count total
end

to color-patches
  if condition >= 0.75 [set pcolor white]
  if condition < 0.75 and condition > 0.50 [set pcolor grey + 2]
  if condition <= 0.50 and condition > 0.25 [set pcolor grey - 2]
  if condition <= 0.25 [set pcolor black]
  if social? [set pcolor red]
end

to set-last-renovated
  if condition <= 0.15 [set last-renovated 120 + random 120]
  if condition > 0.15 and condition <= 0.25 [set last-renovated 60 + random 120]
  if condition > 0.25 and condition <= 0.5 [set last-renovated 60 + random 60]
  if condition > 0.5 and condition <= 0.75 [set last-renovated 24 + random 60]
  if condition > 0.75 [set last-renovated random 48]
end



to determine-phenomenon [place]
  ifelse median [income] of citizens-on patches with [neighbourhood = place] > item 0 table:get allured-districts place
  [
    table:put gentrified-districts place (list median [income] of citizens-on patches with [neighbourhood = place] median [price] of patches with [neighbourhood = place] occupancy place)
    show word "Here is a gentrified neighbourhood: " place
    if write-csv? [export-view (word save-directory "/pics/" "GENTRIFIED_DISTRICT -" "K" Kapital "-t" ticks "-" place ".png")]
    ]
  [
    table:put downfiltered-districts place (list median [income] of citizens-on patches with [neighbourhood = place] median [price] of patches with [neighbourhood = place] occupancy place)
    show word "Here is a downfiltered neighbourhood: " place
    if write-csv? [export-view (word save-directory "/pics/" "DOWNFILTERED_DISTRICT -" "K" Kapital "-t" ticks "-" place ".png")]
    ]
end

to determine-super-phenomenon [district case]  ;; when a place lost than regained uniformity. What's happening???
  ifelse case = 0  [   ;; in this case originally gentrification dissolved uniformity
    ifelse median [income] of citizens-on patches with [neighbourhood = district] >= (item 0 table:get gentrified-districts district - 0.1) and median [price] of patches with [neighbourhood = district] >= (item 1 table:get gentrified-districts district - 0.1)
    [
      show word "Here is a recolonised neighbourhood: " district
      if not member? district recolonisation [set recolonisation fput district recolonisation]
      ;set recolonisation recolonisation + 1
      if write-csv? [export-view (word save-directory "/pics/" "RECOLONISED_DISTRICT -" "K" Kapital "-t" ticks "-" district ".png")]
      ]
    [
      if not member? district degentrification [set degentrification fput district degentrification]
      show word "Here is a DEGENTRIFIED neighbourhood: " district
      ;set degentrification degentrification + 1
      ]
  ] [ ; here originally downfiltering dissolved uniformity
  ifelse mean [income] of citizens-on patches with [neighbourhood = district] <= (item 0 table:get downfiltered-districts district + 0.1)
  [set recreation fput district recreation]
  [set regentrification fput district regentrification]
  ]
end

to go
  ;if fixed-premium? = false [set-premia]
  ifelse ticks mod disp-freq = 0 [set disp? true] [set disp? false]
  ask patches [
    ifelse have-demand-premium [
      ifelse occupancy neighbourhood >= 0.8   ;; NON DEVE ESSERE SOLO NEIGHBOURHOOD !!!
      [set premium 1 + renovation-premium]
      [ifelse occupancy neighbourhood >= 0.5
        [set premium 1 + random-float renovation-premium]
        [set premium 1 + random-float (renovation-premium * 0.8)]
      ]
    ] [set premium 1 + renovation-premium]
    if enable-economy? [
      if gaps = "mean" [set-gaps-mean]
      if gaps = "max" [set-gaps-max]
      if gaps = "unified"  [set-gaps-unified]
      if gaps = "new"  [set-gaps-new]
      if gaps = "lnd"  [set-gaps-lnd]
      decay
      reconsider-price
    ]
    update-emptiness
    ;update-centreness
  ]
  if ticks > 0 and (ticks = 24 or ticks mod 60 = 0) [
    set-city-allure
    foreach districts [
      if occupancy ? > 0.3 [set-allure ?]]
    ]
    ;if ticks < 1000 and any? patches with [allure = 0] [check-new-allure]
  ;if ticks mod 24 = 0 and table:length allured-districts > 0 [check-existing-allure]


  ;; +++++++ ADD SOMETHING HERE TO MONITOR GENTRIFICATION / SEGREGATION (not related to culture) +++++++++++++++

  update-links
  update-dissonance
  update-propensity
  if Mixing? [interact]
  ask citizens [
    set months-here months-here + 1
    if decide-moving [seek-place]
    ; set size 0.01 * months-here
    ; if size >= 1.4 [set size 1.4]
  ]
  if ticks > 0 and ticks mod 6 = 0 [
    if enable-economy? [do-business]
    if inmigration [inmigrate]
    if (any? patches with [social? and not any? citizens-here]) and (table:length housing-waiting-list > 0) [assign-social-housing]
    if any? patches with [social?][check-social-residents]
  ]
  ask patches [color-patches]
  ;cluster-cultures
  ;update-vacancy-rates
  set av-income mean [income] of citizens
  set sd-income standard-deviation [income] of citizens
  set sd-income+ standard-deviation [income] of citizens with [income >= av-income]
  set sd-income- standard-deviation [income] of citizens with [income <= av-income]
  set occupation-rate count patches with [any? citizens-here] / count patches
  check-prices
  if Record? [movie-grab-view]
  tick
  if ticks = end-tick and (write-csv? or paperstuff?) [save-data]
  if paperstuff? and (ticks = 2 or ticks = 300 or ticks = 600 or ticks = 900 or ticks = (end-tick - 1))
  [
    set totalcondition lput wellmaintained totalcondition
    set medianprices lput median [price] of patches with [condition >= 0.15] medianprices
    set median-income lput median [income] of citizens median-income
    ;export-view (word save-directory Kapital "-t" ticks ".png")
    ]
  if ticks = end-tick [
;    if paperstuff? [export-plot "Mean prices by neighbourhood" (word save-directory kapital)]
    if Record? [movie-close]
    stop
  ]
end

to check-social-residents
  ask citizens-on patches with [social?][
    if months-here >= max-time-in-social-housing * 12 [seek-place]
  ]
end

to-report wellmaintained     ;; With this and the function below we check how many districts in the city achieve 75% or more locations with mainiteniance >= 0.50.
  let well 0
  foreach districts [set well well + well-maintained? ?]
  report well
end

to-report well-maintained? [zone]
  let total patches with [neighbourhood = zone]
  if count total with [condition >= 0.49] / count total >= 0.75 [report 1]
  report 0
end

to assign-social-housing
  repeat count patches with [social? and not any? citizens-here] [
    let everybody []
    foreach table:keys housing-waiting-list [set everybody lput turtle ? everybody]
    let candidates sublist everybody 0 4
    let housedperson min-one-of turtle-set candidates [income]
    let locality table:get housing-waiting-list [who] of housedperson
    table:remove housing-waiting-list [who] of housedperson
    ifelse locality != "" and any? patches with [social? and not any? citizens-here and neighbourhood = locality]
    [move-to-social-housing housedperson locality]
    [move-to-social-housing housedperson ""]
  ]
end

to move-to-social-housing [agent area]
  ask agent [
      set breed citizens
      set months-here 0
      set hidden? false
      ifelse area = ""
      [move-to one-of patches with [social? and not any? citizens-here]]
      [move-to one-of patches with [social? and not any? citizens-here and neighbourhood = area]]
  ]
end

to check-prices
  foreach districts [
    ifelse member? ? declining
    [if median [price] of patches with [neighbourhood = ?] >= 0.25 [set declining remove ? declining] ]
    [if median [price] of patches with [neighbourhood = ?] < 0.25 [set declining fput ? declining] ]
    ]
end

to mutate-off
  ask one-of citizens [
    set culture replace-item (random traits) culture (random values)
    ]
end

to mutate
  let where [neighbourhood] of patch-here
  let trait (random traits)
  let most one-of modes [item trait culture] of citizens-on patches with [neighbourhood = where]
  set culture replace-item trait culture most
end

to do-business
  let howmany (Kapital * count patches) / 2
  let goodgap patches with [price-gap >= (price * profit-threshold) and not social? and condition <= 0.8];
  ; let goodgap patches with [price-gap >= profit-threshold]; and condition <= 0.75];
  if count goodgap < howmany [set howmany count goodgap]
  let torenovate max-n-of howmany goodgap [price-gap]
  if any? torenovate with [neighbourhood = "c"][set profit-c sum [price-gap] of torenovate with [neighbourhood = "c"] / sum [price] of torenovate with [neighbourhood = "c"]]
  if any? torenovate with [neighbourhood = "nw"][set profit-nw sum [price-gap] of torenovate with [neighbourhood = "nw"] / sum [price] of torenovate with [neighbourhood = "nw"]]
  if any? torenovate with [neighbourhood = "ne"][set profit-ne sum [price-gap] of torenovate with [neighbourhood = "ne"] / sum [price] of torenovate with [neighbourhood = "ne"]]
  if any? torenovate with [neighbourhood = "sw"][set profit-sw sum [price-gap] of torenovate with [neighbourhood = "sw"] / sum [price] of torenovate with [neighbourhood = "sw"]]
  if any? torenovate with [neighbourhood = "se"][set profit-se sum [price-gap] of torenovate with [neighbourhood = "se"] / sum [price] of torenovate with [neighbourhood = "se"]]
  if any? torenovate with [neighbourhood = "n"][set profit-n sum [price-gap] of torenovate with [neighbourhood = "n"] / sum [price] of torenovate with [neighbourhood = "n"]]
  if any? torenovate with [neighbourhood = "s"][set profit-s sum [price-gap] of torenovate with [neighbourhood = "s"] / sum [price] of torenovate with [neighbourhood = "s"]]
  if any? torenovate with [neighbourhood = "e"][set profit-e sum [price-gap] of torenovate with [neighbourhood = "e"] / sum [price] of torenovate with [neighbourhood = "e"]]
  if any? torenovate with [neighbourhood = "w"][set profit-w sum [price-gap] of torenovate with [neighbourhood = "w"] / sum [price] of torenovate with [neighbourhood = "w"]]
  ask torenovate [renovate]
end

to inmigrate
  let howmany 1 + ((count citizens * immigration-rate) / 2)
  ask n-of howmany people [
    let myprice income
    if any? patches with [price <= myprice and not any? citizens-here and not social?]
    [
      let whoami who
      ; set income random-float 1
      set breed citizens
      set hidden? false
      seek-place
      ifelse table:has-key? housing-waiting-list whoami   ;; if the person is from the housing list we take him away
      [table:remove housing-waiting-list whoami]
      [                                                    ;; if not he becomes a citizen ;-)
        set birthday ticks
        create-culture
        color-agent
        reset-mobility-propensity
      ]
    ]
  ]
end

to color-agent
  if income >= 0.80 [set color green]
  if income < 0.80 and income > 0.5 [set color green + 4]
  if income <= 0.5 and income >= 0.25 [set color violet + 2]
  if income < 0.25 [set color violet - 1]
end

to-report decide-moving
  if ([price] of patch-here > income and not [social?] of patch-here) or (random-float 1 < mobility-propensity) [
    set place-changes place-changes + 1
    report true
  ]
  report false
end

to enter-housing-list [agent place]
  ;; set housing-waiting-list lput (list(agent)(place)) housing-waiting-list
  table:put housing-waiting-list [who] of agent place
  ask agent [
    set breed people
    set hidden? true
    ]
end

to leave-city
  ask my-links [die]
  set breed people
  set hidden? true
end

to renovate
  set price price + price-gap
  if price >= 1 [set price 0.98]
  set condition 0.95
  set last-renovated ticks
end

to decay
   ; if state = "RENTED" [set decay-factor depreciation * 2]  ;; We don't have this yet
   let depr monthly-decay
   let time ticks - last-renovated
   if time < 48 [set depr 0]
   if time >= 48 and time <= 60 [set depr depr / 2]
   if time >= 120 and time <= 240 [set depr depr * 2]
   if not any? citizens-here [set depr depr * 1.20]
   ifelse condition - depr <= 0
      [set condition 0]
      [set condition condition - depr]
   if condition <= 0.2 and social? [set condition 0.55]
end

to reconsider-price
  ifelse social?
  [set price (mean [price] of patches) / 2]
  [
    let depr yearly-depreciation / 12
    let time ticks - last-renovated
    if time <= 48 [set depr 0]
    if time > 48 and time <= 60 [set depr depr / 2]
    if time >= 120 and time <= 240 [set depr depr * 2]
    if months-empty > tolerable-vacancy [set depr depr * 2]
    ifelse price - (price * depr) <= 0
      [set price 0.01]
      [set price price - (price * depr)]
  ]
end

to update-emptiness
  ifelse count citizens-here = 0
  [set months-empty months-empty + 1]
  [set months-empty 0]
end

to update-links
 ask links [    ;; First we check existing links. If the agents are still neighbours we reinforce the relationship, if not we weaken it.
    let stillclose false
    ask one-of both-ends [if neighbourhood = [neighbourhood] of other-end or distance other-end <= 2 [
        set stillclose true] ]
    ifelse stillclose
    [if time < 12 [set time time + 1]]
    [
      set time time - 1
      if time <= 0 [die]
    ]
  ]
  ask citizens [  ;; Then we create new links for neighbours that still don't have one (i.e. new neighbours)
    let myneighbours other citizens with [distance myself <= 2 and link-neighbor? myself = false]
    let goodneighbours myneighbours with [(similarity self myself / traits) >= similarity-for-friendship]
    ask goodneighbours [
      create-link-with myself [
        set time 1
        set hidden? true
      ]
    ]
  ]
end

to build-social-housing [howmany]
  let sofar 0
  let zerop min [price] of patches
  let zeroc min [condition] of patches
  let avg mean [price] of patches with [count citizens-here > 0]
  let firstsocial nobody
  let worst patches with [not any? citizens-here and price <= zerop and condition <= zeroc]
  ifelse any? worst
  [set firstsocial min-one-of worst [price-gap]]
  [set firstsocial max-one-of patches [months-empty]]
  ask firstsocial [
    set social? true
    set price avg / 2
    set condition 0.95
    set sofar sofar + 1
    while [sofar < howmany] [
      ask one-of patches in-radius 4 with [not social?] [
        if not any? citizens-here [
          set social? true
          set price avg / 2
          set condition 0.95
          set sofar sofar + 1
        ]
      ]
    ]
  ]
end

to regenerate
;; Regeneration is intended in the anglo-saxon, "small state but lets-be-compassionate-shall-we" way.
;; Money is put in the areas least desirable to investors (= those with the most narrow price-gap)
;; that are also empty and in run-down condition. These areas are brought to the maximum condition
;; and to the mean price of the city. The idea is to check whether this practice can trigger further private investment.
  let zerop min [price] of patches
  let zeroc min [condition] of patches
  let avg mean [price] of patches with [count citizens-here > 0]
  let worst patches with [not any? citizens-here and price = zerop and condition = zeroc]
  ask min-one-of worst [price-gap] [
    set price avg
    set condition 0.95
    ask neighbors with [not social?] [
      set price avg
      set condition 0.95
    ]
  ]
end

to update-dissonance
  ask citizens [
    ifelse [condition] of patch-here < 0.15 or mean [condition] of other patches in-radius 2 < 0.15
      [set time-in-a-slum time-in-a-slum + 1]
      [set time-in-a-slum 0]
    if PUSH? [
      if count citizens-on neighbors > 0 [
        let alltraits count citizens-on neighbors * traits
        let simil 0
        ask citizens-on neighbors [set simil simil + similarity self myself]
        ifelse (simil / alltraits) <= similarity-for-dissonance
        [set dissonance dissonance + 1]
        [set dissonance 0]
      ]
    ]
  ]
end

to update-propensity
  ask citizens [
    if time-in-a-slum = 0 and dissonance <= tolerable-dissonance [reset-mobility-propensity]
    if ((time-in-a-slum >= 12) and (income > ([price] of patch-here * 1.20)))   ;; If I can afford to, I leave the ghetto
      or (income >= ((median [condition] of neighbors) * 1.50))    ;; This reflects the preference of middle class people towards status over convenience.
      [set mobility-propensity mobility-propensity * 1.50]
    if (dissonance > tolerable-dissonance) [
      set mobility-propensity mobility-propensity * 1.50
      if random-float 1 < 0.05 [mutate]
      ]
    if mobility-propensity > 1 [set mobility-propensity 1]
  ]
end

;; The idea here is that prolonged co-location leads to cultural mixing.
;; We need each household to keep track of how long they have been neighbours with each other
to interact
  ask links with [time >= 12] [
    let a end1
    let c-a [culture] of a
    let b end2
    let c-b [culture] of b
    if c-a != c-b [
;;    if similarity a b < traits [
      let whichone random traits
      let i-a item whichone c-a
      let i-b item whichone c-b
      if i-a != i-b [
        ifelse random 1 = 0
          [ask b [set culture replace-item whichone culture i-a]]
          [ask a [set culture replace-item whichone culture i-b]]
      ]
    ]
  ]
end

to-report entropy [district]
  let common 0
  let thispeople citizens-on patches with [neighbourhood = district]
  let pairs (count thispeople * (count thispeople - 1)) / 2
  ask n-of (count thispeople / 2) thispeople [
    ask other thispeople [
      set common common + (similarity self myself / traits)
    ]
  ]
  report safe-division common pairs
end

to-report entropy-old [district]
  let common 0
  let thispeople citizens-on patches with [neighbourhood = district]
  let pairs (count thispeople * (count thispeople - 1)) / 2
  ask thispeople [
    ask other thispeople [
      set common common + (similarity self myself / traits)
    ]
  ]
  report safe-division (common / 2) pairs
end


; =============================== RESIDENTIAL LOCATION PROCESS =========================================================


;; When seeking a spot we consider vacant affordable places close to the origin (cbd) and with a pleasant cultural mix.
;; This is in line with Jackson et al. 2008, although they have a Schelling-like ethnic (not cultural) mix.
;; In this version agents only evaluate the CULTURAL ALLURE of a district, not the STATUS.
;; If we are to finegrain the model we could also include status in the decision process.

to seek-place
  ifelse PULL? and table:length allured-districts > 0
  [
    let where set-place
    ifelse where != "" [
      ifelse strong-neighbourhood?
      [relocate-to where]
      [weak-relocate-to where]
    ][relocate]
  ]
   [relocate]
end

to-report set-place         ;;     ========= nononon questo si deve cambiare per rflettera la nuova composiziopne della allure che abbiamo appena fatto...
  let best_ftr 1
  let bestdistrict ""
  foreach table:keys allured-districts [
    let this_similarity similarity self one-of patches with [neighbourhood = ?]
    if this_similarity >= best_ftr [
      set best_ftr this_similarity
      set bestdistrict ?
      ]
    ]
  report bestdistrict
end

to relocate
  set months-here 0
  let baseline patches with [(count citizens-here = 0) and (condition > 0) and (social? = false)]
  if enable-economy? [set baseline baseline with [(price <= [income] of myself)]]
  ifelse any? baseline [
    let testbed n-of 5 patches
;    let secondbest baseline with [(price <= [income] of myself) and (count citizens-here = 0) and (condition >= (mean [condition] of testbed - (mean [condition] of testbed * 0.15 )))]  ;; if we can't find a place we like then we move to one we can afford
    let secondbest baseline with [(price <= [income] of myself) and (count citizens-here = 0) and (condition >= 0.25)]  ;; if we can't find a place we like then we move to one we can afford
    ifelse any? secondbest
    [move-to min-one-of secondbest [dist]]
    [move-to min-one-of baseline [dist]]
  ]
  [enter-housing-list self ""]
end

to relocate-to [place]
  set months-here 0
  let baseline patches with [(price <= [income] of myself) and (count citizens-here = 0) and (condition > 0) and (social? = false)] ;Add to prevent people from moving to decrepit loc:; and (condition > 0)
  ifelse any? baseline [
    ;let testbed n-of 5 patches
    ;let condi mean [condition] of testbed
    ;let ideal baseline with [(neighbourhood = place) and (condition >= (condi - (condi * 0.15 )))]
    let ideal baseline with [(neighbourhood = place) and (condition > 0.25)]
    ifelse any? ideal
      [move-to min-one-of ideal [local-dist]]
      [
        let apex patches with [centre? = true and neighbourhood = place]
        let acceptable baseline with [condition >= 0.10]    ;;; change this: acceptable condition should vary across agents
        let secondbest acceptable with [neighbourhood = place] ;; change this: if nothing is available in place look at the edges
        ifelse any? secondbest
        [move-to min-one-of secondbest [local-dist]]
        [ifelse any? acceptable
          [move-to min-one-of acceptable [distance one-of apex]]   ;; If we can't find anything in the desired area we try somewhere close
          [move-to min-one-of baseline [dist]]
        ]
     ]
  ]
  [enter-housing-list self place]
end

to weak-relocate-to [place]
    let ideal patches with [(price <= [income] of myself) and (count citizens-here = 0) and (neighbourhood = place) and (condition >= (mean [condition] of patches - (mean [condition] of patches * 0.15 )))]
    ifelse any? ideal
    [move-to min-one-of ideal [dist]]
    [ let testbed n-of 5 patches
      let secondbest patches with [(price <= [income] of myself) and (count citizens-here = 0) and (condition >= (mean [condition] of testbed - (mean [condition] of testbed * 0.15 )))]  ;; if we can't find a place we like then we move to one we can afford
      ifelse any? secondbest
      [move-to min-one-of secondbest [dist]]
      [let thirdbest patches with [(price <= [income] of myself) and (count citizens-here = 0)  ] ;; Uncomment the following to prevent people from moving in decrepit locations ;and (condition > 0)
       ifelse any? thirdbest [move-to min-one-of thirdbest [dist]] [enter-housing-list self place]  ;; if no place exists we leave the city.
      ]
    ]
end

; =============================== PRICE GAPS ====================================


to set-gaps-lnd-off
  let sample max [price] of patches in-radius 3
  let areaprice median [price] of patches with [neighbourhood = [neighbourhood] of myself] * (1 + renovation-premium)
  let whichprice sample
  if areaprice > sample [set whichprice areaprice]
  ifelse whichprice > price
  [set price-gap (sample - price)]
  [set price-gap 0]
end

to set-gaps-lnd
  let whichprice 0
  let neigh-price 0
  let areaprice 0
  let sample patches in-radius 2 with [count citizens-here > 0]
  ifelse any? sample
  [set areaprice mean [price] of sample]
  [set areaprice (mean [price] of patches in-radius 2) * 0.65]
  set whichprice areaprice * (1 + renovation-premium)
  ifelse whichprice > price
    [
      ifelse any? citizens-here with [income < whichprice / 2]
      [set price-gap (whichprice - (price + (resident-removal-cost * price)))]   ;; we anticipate whether we will have to kick someone out
      [set price-gap (whichprice - price)]
    ]
    [set price-gap 0]
end


to set-gaps-new   ;; Maximum of moore neighbourhood or district median
 let whichprice 0
 let neigh-price 0
 let area-price 0
 set neigh-price max [price] of neighbors
 set area-price median [price] of patches with [neighbourhood = [neighbourhood] of myself] * premium
 ifelse neigh-price > area-price
 [set whichprice neigh-price]
 [set whichprice area-price]
 ifelse whichprice > price
 [ifelse any? citizens-here with [income < whichprice]     ; We anticipate whether we will have to kick someone out...
    [set price-gap (whichprice - (price + resident-removal-cost))]              ; The removal cost affects the profit prospect...
    [set price-gap (whichprice - price)]
  ]
  [set price-gap 0]
end

to set-gaps-unified  ;;
 let whichprice 0
 let localprice mean [price] of neighbors * (1 + renovation-premium)
 if occupancy neighbors >= 0.85 [set localprice max [price] of neighbors * (1 + renovation-premium) ]
 ifelse occupancy neighbourhood >= 0.85
 [set whichprice max [price] of patches with [neighbourhood = [neighbourhood] of myself] * (1 + renovation-premium)]
 [set whichprice mean [price] of patches with [neighbourhood = [neighbourhood] of myself] * (1 + renovation-premium)]
 if localprice > whichprice [set whichprice localprice]
 ifelse whichprice > price
 [ifelse any? citizens-here with [income < whichprice]     ; We anticipate whether we will have to kick someone out...
    [set price-gap (whichprice - (price + resident-removal-cost))]              ; The removal cost affects the profit prospect...
    [set price-gap (whichprice - price)]
  ]
  [set price-gap 0]
end

to set-gaps-mean
 let whichprice 0
 let localprice mean [price] of neighbors * premium
 ;if count citizens-on neighbors / count neighbors >= 0.85 [set localprice max [price] of neighbors * premium ]
 ;ifelse occupancy neighbourhood >= 0.85
 ;[set whichprice max [price] of patches with [neighbourhood = [neighbourhood] of myself] * premium]
 set whichprice mean [price] of patches with [neighbourhood = [neighbourhood] of myself] * premium
 if localprice > whichprice [set whichprice localprice]
 ifelse whichprice > price
 [ifelse any? citizens-here with [income < whichprice]     ; We anticipate whether we will have to kick someone out...
    [set price-gap (whichprice - (price + resident-removal-cost))]              ; The removal cost affects the profit prospect...
    [set price-gap (whichprice - price)]
  ]
  [set price-gap 0]
end

to set-gaps-max
 set premium 1.001
 let whichprice 0
 let localprice max [price] of neighbors * premium
 ;if count citizens-on neighbors / count neighbors >= 0.85 [set localprice max [price] of neighbors * premium ]
 ;ifelse occupancy neighbourhood >= 0.85
 ;[set whichprice max [price] of patches with [neighbourhood = [neighbourhood] of myself] * premium]
 set whichprice max [price] of patches with [neighbourhood = [neighbourhood] of myself] * premium
 if localprice > whichprice [set whichprice localprice]
 ifelse whichprice > price
 [ifelse any? citizens-here with [income < whichprice]     ; We anticipate whether we will have to kick someone out...
    [set price-gap (whichprice - (price + resident-removal-cost))]              ; The removal cost affects the profit prospect...
    [set price-gap (whichprice - price)]
  ]
  [set price-gap 0]
end


; =================== ALLURE ====================================================

to-report update-city-culture
  let newallure n-values traits [0]
  let trt 0
  while [trt < traits] [
    let thistrait one-of modes [item trt culture] of citizens
    set newallure replace-item trt newallure thistrait
    set trt trt + 1
  ]
  report newallure
end

to set-city-allure
  let city-culture update-city-culture
  let pallure []
  let trait 0
  while [trait < traits] [
    set pallure lput ifelse-value (count citizens with
      [(item trait culture = item trait city-culture)] >= (count citizens * 0.3))
    [item trait city-culture] ["x"] pallure
    set trait trait + 1
    ]
  set city-allure pallure
end

to-report localculture [district]
  if any? citizens-on patches with [neighbourhood = district] [
    let people-here citizens-on patches with [neighbourhood = district]
    let newallure n-values traits [0]
    let trt 0
    while [trt < traits] [
      let thistrait one-of modes [item trt culture] of people-here
      set newallure replace-item trt newallure thistrait
      set trt trt + 1
    ]
    report newallure
   ; ask patches with [neighbourhood = district] [set pculture newallure]
  ]
end

to set-allure [place]
  let ppl citizens-on patches with [neighbourhood = place]
  let areaculture localculture place
  let pallure []
  let trait 0
  while [trait < traits] [
    set pallure lput ifelse-value
    (count ppl with [item trait culture = item trait areaculture] > count ppl * 0.3 and
      item trait areaculture != item trait city-allure and
      item trait city-allure != "x"
      )
    [item trait areaculture] ["x"] pallure
    set trait trait + 1
  ]
  let peculiar length filter [? != "x"] pallure
  set-current-plot "peculiarity"
  set-current-plot-pen place
  plotxy ticks peculiar
  ifelse peculiar > peculiarity-for-allure [
    ask patches with [neighbourhood = place] [set allure pallure]
    if not table:has-key? allured-districts place
    [table:put allured-districts place (list (median [income] of citizens-on patches with [neighbourhood = place]) (median [price] of patches with [neighbourhood = place]) (occupancy place) (ticks))]
  ]
  [if table:has-key? allured-districts place [
      let longevity ticks - item 3 table:get allured-districts place
      if longevity > 60 [table:remove allured-districts place]]
  ]
end

; =================== SUPPORTING ====================

to-report safe-division [a b]
  if a = 0 or b = 0 [report 0]
  report a / b
end

to-report similarity [a b]
  report similarity-of ([culture] of a) (ifelse-value is-turtle? b [[culture] of b] [[allure] of b])
end

to-report similarity-of [ls1 ls2]                    ;;;;;; DA QUA DOBBIAMO PRENDERE IL CODICE PER FARE IL NUOVO ENTROPY
  report length filter [?] (map [?1 = ?2] ls1 ls2)
end



; =================== PLOTTING ====================================================

to plot-ent [dis]
  if disp? [repeat disp-freq [plot entropy dis]]
end

to-report medianincome [area]
  ifelse any? citizens-on patches with [neighbourhood = area] [
    report median [income] of citizens-on patches with [neighbourhood = area]
  ][report 0]
end

; =========================== DATA OUTPUT ==========================================

to prepare-data-save
  let run-number 0
  ;let maxmean "MEAN"
  let pull ""
  let mix ""
  ;if areamax? [set maxmean "MAX"]
  if PULL? [set pull "PULL"]
  if behaviorspace-run-number != 0 [set run-number behaviorspace-run-number]
  ;set file-name-entropy (word save-directory "gentax-" version "-ENTROPY-" pull "-K" Kapital "-#" run-number ".csv")
  ;set file-name-pop (word save-directory "gentax-" version "-POPULATION-" pull "-K" Kapital "-#" run-number ".csv")
  ;set file-name-prices (word save-directory "gentax-" version "-PRICES-" pull "-K" Kapital "-#" run-number ".csv")
  ;set file-name-donut (word save-directory "gentax-" version "-DONUT-" pull "-K" Kapital "-#" run-number ".csv")
  ;set file-name-income (word save-directory "gentax-" version "-INCOME-" pull "-K" Kapital "-#" run-number ".csv")
  set file-name-repair (word save-directory "gentax-" version "-ALL.csv")
  ;set file-name-allured (word save-directory "gentax-" version "-ALLURE.csv")
  ;file-delete file-name-entropy
  ;file-delete file-name-pop
  ;file-delete file-name-prices
  ;file-delete file-name-income
  ;file-open file-name-entropy
  ;file-write "ticks;"
  ;foreach districts [file-write (word ? ";")]
  ;file-print ""
  ;file-open file-name-pop
  ;file-write "ticks;"
  ;foreach districts [file-write (word ? ";")]
  ;file-print ""
  ;file-open file-name-prices
  ;file-write "ticks;"
  ;foreach districts [file-write (word ? ";")]
  ;file-print ""
  ;file-open file-name-income
  ;file-write "ticks;"
  ;foreach districts [file-write (word ? ";")]
  ;file-print ""
  ;file-open file-name-donut
  ;file-print "ticks;centre;semicentre;periphery"
  ;file-open file-name-repair
 ; file-print "K;300;600;900;end-tick"
 ; file-close-all
end

to save-data
  let run-number 0
  if behaviorspace-run-number != 0 [set run-number behaviorspace-run-number]
  ;file-open file-name-entropy
  ;file-write (word ticks ";")
  ;foreach districts [file-write (word entropy ? ";")]
  ;file-print " "
  file-open file-name-repair    ;; we write a large file with all the runs.
  file-print (word run-number ";" Kapital ";" gaps ";" profit-threshold ";" immigration-rate ";" totalcondition ";" medianprices ";" median-income ";" median [income] of citizens-on patches with [distancexy 0 0 < 4] ";" median [income] of citizens-on patches with [distancexy 0 0 >= 4 and distancexy 0 0 < 8] ";" median [income] of citizens-on patches with [distancexy 0 0 >= 8])
  ;file-open (word Kapital ";" run-number ";" gaps ";" file-name-pop)
  ;file-write (word ticks ";")
  ;foreach districts [file-write (word count citizens-on patches with [neighbourhood = ?] ";")]
  ;file-print " "
  ;file-write (word ticks ";")
  ;foreach districts [file-write (word mean [price] of patches with [neighbourhood = ?] ";")]
  ;file-print " "
  ;file-open file-name-donut
  ;file-print (word ticks ";" median [income] of citizens-on patches with [distancexy 0 0 < 4] ";" median [income] of citizens-on patches with [distancexy 0 0 >= 4 and dist < 8] ";" median [income] of citizens-on patches with [distancexy 0 0 >= 8])
  ;file-open file-name-income
  ;file-write (word ticks ";")
  ;foreach districts [file-write (word safe-division sum [income] of citizens-on patches with [neighbourhood = ?] count citizens-on patches with [neighbourhood = ?] ";")]
  ;file-print " "
;  if ticks = end-tick [
;    let current-allure 0
;    foreach districts [
;      if (entropy ? >= similarity-for-allure and occupancy ? > 0.3) [set current-allure current-allure + 1]
;    ]
;    file-open file-name-allured
;    ; file-print (word "kapital;total;final;first-emerged;max-longevity;run-number")
;    file-print (word Kapital ";" table:length allured-districts ";" current-allure ";" firstallure ";" [al-longevity] of one-of patches with-max [al-longevity] ";" run-number)
;  ]
  if Record? [movie-grab-view]
  ;[
   ; if ticks = 300 or ticks = 600 or ticks = 900 or ticks = end-tick or ticks = end-tick [
    ;  set file-name-world (word save-directory "gentax-" version "-world-k" Kapital "-#" run-number "_" ticks ".png")
    ;  export-view file-name-world
   ; ]
  ;]
  file-close-all
end
@#$#@#$#@
GRAPHICS-WINDOW
4
10
560
587
10
10
26.0
1
10
1
1
1
0
0
0
1
-10
10
-10
10
1
1
1
Months
30.0

SLIDER
769
527
943
560
monthly-decay
monthly-decay
0
0.1
0.0012
0.0001
1
NIL
HORIZONTAL

SLIDER
770
561
944
594
tolerable-vacancy
tolerable-vacancy
0
24
8
1
1
months
HORIZONTAL

SLIDER
1072
490
1208
523
prob-move
prob-move
0
0.01
0.002
0.0001
1
NIL
HORIZONTAL

SLIDER
579
617
671
650
traits
traits
1
10
10
1
1
NIL
HORIZONTAL

SLIDER
672
618
765
651
values
values
1
10
4
1
1
NIL
HORIZONTAL

TEXTBOX
579
521
640
539
CULTURE
12
0.0
1

SLIDER
1070
562
1207
595
immigration-rate
immigration-rate
0
0.2
0.03
0.0001
1
NIL
HORIZONTAL

SLIDER
946
559
1065
592
init-gini
init-gini
0
1
0.279
0.001
1
NIL
HORIZONTAL

SLIDER
1070
454
1208
487
N-Agents
N-Agents
0
count patches
250
1
1
NIL
HORIZONTAL

SWITCH
945
525
1066
558
random-income?
random-income?
1
1
-1000

SLIDER
567
455
659
488
Kapital
Kapital
0
0.1
0.03
0.001
1
NIL
HORIZONTAL

PLOT
563
10
878
223
Mean prices by neighbourhood
NIL
NIL
0.0
1400.0
0.4
1.0
true
true
"" ""
PENS
"C" 1.0 0 -16777216 true "" "plot median [price] of patches with [neighbourhood = \"c\"]"
"NW" 1.0 0 -8275240 true "" "plot median [price] of patches with [neighbourhood = \"nw\"]"
"NE" 1.0 0 -5298144 true "" "plot median [price] of patches with [neighbourhood = \"ne\"]"
"SW" 1.0 0 -9276814 true "" "plot median [price] of patches with [neighbourhood = \"sw\"]"
"SE" 1.0 0 -2064490 true "" "plot median [price] of patches with [neighbourhood = \"se\"]"
"E" 1.0 0 -1184463 true "" "plot median [price] of patches with [neighbourhood = \"e\"]"
"W" 1.0 0 -8431303 true "" "plot median [price] of patches with [neighbourhood = \"w\"]"
"N" 1.0 0 -14070903 true "" "plot median [price] of patches with [neighbourhood = \"n\"]"
"S" 1.0 0 -12087248 true "" "plot median [price] of patches with [neighbourhood = \"s\"]"
"CITY" 1.0 0 -7500403 true "" "plot median [price] of patches"

SWITCH
1073
525
1207
558
inmigration
inmigration
0
1
-1000

SLIDER
579
653
766
686
tolerable-dissonance
tolerable-dissonance
0
24
5
1
1
months
HORIZONTAL

SLIDER
579
685
766
718
similarity-for-dissonance
similarity-for-dissonance
0
0.5
0.2
0.01
1
NIL
HORIZONTAL

MONITOR
1165
669
1223
714
Pop
count citizens
0
1
11

SLIDER
770
490
942
523
profit-threshold
profit-threshold
0
1
0.2
0.001
1
NIL
HORIZONTAL

PLOT
884
229
1198
422
Mean income by neighbourhood
NIL
NIL
0.0
1400.0
0.3
1.0
false
true
"" ""
PENS
"CBD" 1.0 0 -16777216 true "" "if any? citizens-on patches with [neighbourhood = \"c\"]  [plot mean [income] of citizens-on patches with [neighbourhood = \"c\"]]"
"NW" 1.0 0 -8275240 true "" "if any? citizens-on patches with [neighbourhood = \"nw\"]  [plot mean [income] of citizens-on patches with [neighbourhood = \"nw\"]]"
"NE" 1.0 0 -5298144 true "" "if any? citizens-on patches with [neighbourhood = \"ne\"]  [plot mean [income] of citizens-on patches with [neighbourhood = \"ne\"]]"
"SW" 1.0 0 -9276814 true "" "if any? citizens-on patches with [neighbourhood = \"sw\"]  [plot mean [income] of citizens-on patches with [neighbourhood = \"sw\"]]"
"SE" 1.0 0 -2064490 true "" "if any? citizens-on patches with [neighbourhood = \"se\"]  [plot mean [income] of citizens-on patches with [neighbourhood = \"se\"]]"
"E" 1.0 0 -1184463 true "" "if any? citizens-on patches with [neighbourhood = \"e\"]  [plot mean [income] of citizens-on patches with [neighbourhood = \"e\"]]"
"W" 1.0 0 -8431303 true "" "if any? citizens-on patches with [neighbourhood = \"w\"]  [plot mean [income] of citizens-on patches with [neighbourhood = \"w\"]]"
"N" 1.0 0 -14070903 true "" "if any? citizens-on patches with [neighbourhood = \"n\"]  [plot mean [income] of citizens-on patches with [neighbourhood = \"n\"]]"
"S" 1.0 0 -12087248 true "" "if any? citizens-on patches with [neighbourhood = \"s\"]  [plot mean [income] of citizens-on patches with [neighbourhood = \"s\"]]"

SWITCH
579
583
669
616
PUSH?
PUSH?
0
1
-1000

SWITCH
576
743
685
776
Record?
Record?
1
1
-1000

SWITCH
672
583
762
616
strong-neighbourhood?
strong-neighbourhood?
0
1
-1000

SWITCH
672
547
762
580
PULL?
PULL?
0
1
-1000

SWITCH
578
547
670
580
Mixing?
Mixing?
0
1
-1000

SWITCH
688
743
803
776
write-csv?
write-csv?
1
1
-1000

BUTTON
1128
631
1202
664
Show allure
ask patches with [allure != 0][set pcolor yellow]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1205
631
1270
664
Undisplay
ask patches [color-patches]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
587
433
651
451
ECONOMY
12
0.0
1

TEXTBOX
1073
437
1223
455
POPULATION
12
0.0
1

TEXTBOX
579
725
629
743
OUTPUT
12
0.0
1

CHOOSER
1213
454
1375
499
kind
kind
"monocentric" "policentric" "no centres"
1

BUTTON
1016
630
1125
665
Highlight centres
ask patches with [centre? = true][set pcolor blue]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
1213
437
1363
455
CITY
12
0.0
1

SLIDER
1213
502
1444
535
peculiarity-for-allure
peculiarity-for-allure
0
traits
2
1
1
/ 10 traits
HORIZONTAL

SLIDER
1070
597
1208
630
similarity-for-friendship
similarity-for-friendship
0
1
0.2
0.01
1
NIL
HORIZONTAL

SLIDER
770
597
945
630
resident-removal-cost
resident-removal-cost
0
0.25
0.05
0.001
1
NIL
HORIZONTAL

SLIDER
945
490
1066
523
renovation-premium
renovation-premium
0
1
0.2
0.01
1
NIL
HORIZONTAL

SWITCH
806
743
922
776
paperstuff?
paperstuff?
0
1
-1000

MONITOR
1395
619
1452
664
Mobility
sum [place-changes] of turtles / count turtles
2
1
11

BUTTON
1303
540
1384
573
Regeneration
regenerate
NIL
1
T
OBSERVER
NIL
R
NIL
NIL
1

SWITCH
945
455
1065
488
fixed-premium?
fixed-premium?
0
1
-1000

PLOT
292
593
562
785
Income Dist
Income
Freq
0.0
1.05
0.0
1.0
true
false
"set-histogram-num-bars 20" "histogram [income] of citizens"
PENS
"default" 1.0 1 -16777216 true "" ""

MONITOR
1225
670
1275
715
Total Gini
gini people
2
1
11

MONITOR
1278
671
1336
716
Occ. R.
occupation-rate
2
1
11

PLOT
6
592
286
784
Price Distribution
Price
Freq
0.0
1.05
0.0
1.0
true
false
"set-histogram-num-bars 20" "histogram [price] of patches with [count citizens-here > 0]"
PENS
"default" 1.0 1 -2674135 true "" ""

SWITCH
643
513
762
546
enable-culture
enable-culture
0
1
-1000

MONITOR
922
670
984
715
% Slums
count citizens-on patches with [condition <= 0.25] / count turtles
17
1
11

MONITOR
1335
618
1393
663
City Gini
gini citizens
17
1
11

BUTTON
1214
540
1301
573
Build SH
build-social-housing 4
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

SLIDER
1215
576
1385
609
max-time-in-social-housing
max-time-in-social-housing
0
100
50
1
1
NIL
HORIZONTAL

MONITOR
1275
617
1331
662
Waiting list
table:length housing-waiting-list
17
1
11

SLIDER
771
632
943
665
yearly-depreciation
yearly-depreciation
0
0.1
0.02
0.001
1
NIL
HORIZONTAL

BUTTON
947
630
1013
663
RUN!
setup\nrepeat 1440 [go]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
948
595
1003
628
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1005
595
1060
628
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
985
670
1042
715
Centre
median [income] of citizens-on patches with [dist < 4]
4
1
11

MONITOR
1046
669
1103
714
Semi
median [income] of citizens-on patches with [dist >= 4 and dist < 8]
4
1
11

MONITOR
1105
669
1162
714
Far
median [income] of citizens-on patches with [dist >= 8]
4
1
11

PLOT
880
10
1213
223
Income: Centre vs. Suburb
NIL
NIL
0.0
1400.0
0.3
1.0
false
true
"" ""
PENS
"Centre" 1.0 0 -16777216 true "" "plot median [income] of citizens-on patches with [distancexy 0 0 < 4]"
"Semi" 1.0 0 -2674135 true "" "plot median [income] of citizens-on patches with [distancexy 0 0 >= 4 and distancexy 0 0 < 8]"
"Subs" 1.0 0 -14730904 true "" "plot median [income] of citizens-on patches with [distancexy 0 0 >= 8]"

PLOT
1201
229
1531
422
Prices
NIL
NIL
0.0
1400.0
0.0
1.0
false
false
"" ""
PENS
"Price" 1.0 0 -16777216 true "" "plot median [price] of patches"
"Income" 1.0 0 -2674135 true "" "plot median [income] of citizens"

MONITOR
1378
454
1435
499
Allure?
table:length allured-districts
17
1
11

PLOT
1215
11
1530
226
peculiarity
NIL
NIL
0.0
1400.0
0.0
11.0
true
true
"" ""
PENS
"nw" 1.0 0 -8990512 true "" ""
"ne" 1.0 0 -2674135 true "" ""
"sw" 1.0 0 -11053225 true "" ""
"se" 1.0 0 -1069655 true "" ""
"s" 1.0 0 -15575016 true "" ""
"n" 1.0 0 -14730904 true "" ""
"e" 1.0 0 -1184463 true "" ""
"w" 1.0 0 -10402772 true "" ""
"c" 1.0 0 -16777216 true "" ""

CHOOSER
661
444
753
489
gaps
gaps
"mean" "max" "unified" "new" "lnd"
0

SWITCH
772
666
915
699
have-demand-premium
have-demand-premium
0
1
-1000

SWITCH
756
444
907
477
enable-economy?
enable-economy?
0
1
-1000

PLOT
562
226
879
423
Profit
NIL
NIL
0.0
1400.0
0.1
2.0
false
true
"" ""
PENS
"C" 1.0 0 -16777216 true "" "plot profit-c"
"SW" 1.0 0 -7500403 true "" "plot profit-sw"
"NE" 1.0 0 -2674135 true "" "plot profit-ne"
"E" 1.0 0 -987046 true "" "plot profit-e"
"S" 1.0 0 -14439633 true "" "plot profit-s"
"SE" 1.0 0 -1664597 true "" "plot profit-se"
"N" 1.0 0 -13345367 true "" "plot profit-n"
"NW" 1.0 0 -8275240 true "" "plot profit-nw"
"W" 1.0 0 -6459832 true "" "plot profit-w"
"POTENTIAL" 1.0 0 -955883 true "" "if ticks > 2 [plot sum [price-gap] of patches with [price-gap > profit-threshold * price]]"

INPUTBOX
948
725
1028
785
end-tick
1200
1
0
Number

@#$#@#$#@
# Introduction
*Gentrification meets Axelrod meets Schelling.*

This is a city-scale residential mobiliy model. It couples residential choice with cultural dynamics and investment/disinvestment cycles, modelled, the latter, according to Neil Smith's (RIP) rent-gap theory.
Dwellings (individual patches) have a price and a mainteniance condition. They progressively decay in their condition and, accordingly, in their asking price.
If sufficient Kapital is available, renovation is carried out on those locations that present the wider "price-gap" with the neighbouring properties, as proposed in most computational implementations of the rent-gap theory.
After renovation a property is reset to the highest possible condition and is able to charge a price equal to the average of neighbouring properties + a 15% premium.

Agents are created with a wealth level, a mobility propensity and a n-th dimensional string representing their culture; they mix traits with neighbours and have a homophily preference when selecting a place of residence.

The aim of the model is to explore the effects of different levels of capital available for redevelopment on price dynamics, residential dynamics and cultural diversity.

# Model detail
## Agent model
The agent's **culture** is modelled as a n-th dimensional multi-value string (currently n=10) of "traits", as in the great tradition of "string culture" (Axelrod, etc.)
The agent's **income level** is set at random, normalized to the interval 0-1. No "social mobility" exists: income is a fixed attribute and never changes.
Agents are also created with a **mobility-propensity** parameter, which is very low in the beginning (the initial probability to move is poisson distributed in the population centred on 0.001/month).

### Micro-level cultural dynamics
Long time neighbouring agents with at least one common trait are more likely to interact and exchange traits, thus rendering the respective cultural strings more similar. A **cultural cognitive dissonance** parameter implements a concept proposed by Portugali (1996): this is, roughly, the frustration of being surrounded by too many culturally distant agents. Yes, it's Schelling in other terms.

### Residential mobility
One agent's mobility propensity attribute is increased when:

* Excessive time is spent in a dwelling in very bad condition (slum)
* The cultural cognitive dissonance level is high for too long (cultural push).
* The price of the dwelling currently occupied exceeds the agent's income (in this case the agent is automatically put in "seek new place" mode)

A new dwelling has to be:

* affordable
* in relatively good condition
* as close as possible to the centre of the city
* located in a culturally appealing neighbourhood (cultural pull).

## Land dynamics
The city is divided in 8 neighbourhoods + the CBD. 441 patches total

Dwellings' price and condition are initially set at a random value normalized in the 0-1 interval, with price being set at 0.25 above condition. Decay happens at every step by a fixed factor (currently 0.0016 per month, meaning that a property decays from 1 to 0 in 50 years) which is increased by 25% when the dwelling is empty. The price of the dwelling is adjusted every year and is decreased if the dwelling has been empty.

If the cultural makeup of the residents is sufficiently homogeneous a neighbourhood can develop an "**allure**", or reputation, based on the average cultural configuration of its inhabitants. This attribute is visible to perspective movers and tends to be "sticky", i.e. is updated seldom and not always reflects the actual composition of the neighbourhood.

The allure of a district, in other words, is not imposed from the beginning, instead it is an emergent feature. Allure is initially blank (meaning that the area has no particular connotation), when cultural uniformity reaches a threshold (see update-allure function) the allure is set. This is to reflect the fact that not every neighbourhood has a special connotation in the mind of agents, but only those with a recognizable population (e.g. WOW! HIPPIES LIVE THERE, I WANT IN!!)


### Residential movement process
When an agent is set to relocate, or first enters the system, compares its culture string to the allure of each neighbourhood that have one, and finds the empty spots within the neighbourhood most similar to himself. Among the empty spots, the affordable ones are detected and among these, the agent moves to the one in the best condition and closest to the centre. Failing to find a suitable spot results in the agent trying in a different neighbourhood, then lowering its requirements and ultimately leaving the city.

# Results
## THE PROBLEM OF SETTING A LOCATION TO THE "HIGHEST AND BEST USE"

Setting the price to the maximum or the average makes a huge difference, regardless of the scope of the area considered.
Only gaps set to average (local or area based) give rise to the typical "uneven development" scenario, where one area attracts all the investment where the rest rot to hell. Interestingly the premium and the amount of available capital only determine the speed and the scope of the process, whereas ultimately average or maximum determine the shape of the dynamic.


## Effects of investment levels on house prices and distribution of agents
### The role of Kapital
In this model (and in the real world) Kapital has a dual role. A sufficient amount of K is necessary to ensure that every property in the city is mainteined and inhabitable, but the nomadic nature of K, which travels across the city in pursuit of the highest profit, generates shocks in the form of abrupt spikes in prices, which affect the ability of (especially least well off) agents to stay or move to the spot of choice. From this duality arise, ultimately, all the dynamics that we see occurring in the model.

The model runs for 1200 ticks = 100 years.

For low levels of investment (**Kapital < 15** = ~3.4% of dwellings receiving investment each year) prices collapse in every neighbourhood and no clear differences in maintenance levels emerge: refurbished patches are scattered across the city. In this condition the population increases to its maximum and the income is average, since very low-priced housing is accessible to everybody.
**Version 0.2 Update** In the 0.2 version (with a threshold on investments being introduced, see above) after a while the city is no longer able to attract Kapital, because no patches present a sufficiently wide price-gap and all patches end up in the slum condition.

At **Kapital > 15** a pattern is visible: the centre of the city and the immediate surrounding area are constantly being maintained and achieving high prices, while the remaining neighbourhoods tend to very low prices and maintenance levels. Investments concentrate in the central area, where price gaps are systematically higher.

When Kapital reaches **K=25** (~6% of dwellings being refurbished each year) two or three entire neighbourhoods are able to attract all the investments. In this case the city tends to divide into two distinct areas, roughly of the same size: one with high price / high repair condition and one of slums.

Around this value the most interesting effects emerge. Gentrification can be spotted often, with neighbourhoods steadily increasing the mean income while the population decreases and increase abruptly, often in several waves, signalling that the poor go and the rich come.

A **Kapital > 35** (refurbishing 8% per year) is able to trigger high prices/ high mainteniance in the whole city. The population is very low because only the richest immigrants can afford to enter the city.
Interestingly, dissonance levels tend to be higher with higher investments. Even though there is no relation between income levels and culture, a high priced / highly selective city makes it difficult for agents to find compatible neighbours. Because the low population doesn't add enough diversity to the mix, a sort of "boring little village" effect or "boring white flight suburb" effect emerges.

### UPDATE 0.2.3
Changing the mechanism for setting the price-gaps (see changelog), somehow, made capital more effective end efficient in the way it distributed the benefit of renovation across the city. Without being bounded by the immediate Moore neighbourhood it was even more effective.
No. It was the constraint towards repairing locations with condition < 0.75 that generated this effect.


Now less capital is capable of spreading the renovation effect to a wider area. As little as K=12 (2.7%) is capable of generating a neighbourhood in good state of repair for 1400 ticks and K=14 generates two neighbourhoods raising to the highest price levels.

## Cultural dynamics
### The emergence and sustainment of culturally homogeneous neighbourhoods

The initial emergence of a recognizable, culturally homogeneous, neighbourhood, ultimately, depends on the availability of decent housing at a medium/low price. Long periods of stable or decreasing prices allow the agents to stay put and interact, becoming more and more similar. This is the only way for a neighbourhood to emerge in the first place. Because of the random initial distribution of prices and repair conditions (and therefore price gaps), in the initial steps of the simulation the locations being renovated are scattered throughout the city and a couple of hundreds of steps are needed before the clustering of investments happens. In this interval the mean prices of individual neighbourhoods tend to decrease and the first neighbourhood emerges, usually the CBD. This is because the agents have a preference for living towards the centre of the city, therefore CBD is the first district to fill and the first localtion where many bagents start to interact.

The fate of the early uniform neighbourhoods depends on the trajectories of Kapital. If the prices keep falling and the dwellings keep decaying eventually the community dissolves, because agents have limited tolerance towards living in a slum... If prices start to rise, as a consequence of Kapital flowing in, the place is bound to genrtify and lose its cultural uniformity. **The fate of many a working class neighbourhood is accurately reproduced in the model!**

Gentrification doesn't always dissolve cultural homogeneity, though. At this stage much also depends on the processes going on in the rest of the city. If other neighbourhoods in the city are decaying, for example, an outflow of agents is to be expected, and since there is one "allured" neighbourhood recognizable, some agents can relocate to a location that reflects better their cultural makeup, reinforcing the homogeneity. Correlation between decreasing prices in one area and increasing uniformity in another is frequent, signalling that this is a recurring dynamic.

In general, abrupt shifts in prices seem to always have a disruptive effect on cultural homogeneity. A high-prices+high-uniformity district where prices start to fall sees an influx of "parvenues" which dilute the uniformity. A low-price+high-uniformity district where prices start to rise displaces some of the residents.



# Changelog

## Version 0.2.15
### NEW ALLURE CODE

We define allure as *locally over-represented minority cultural traits*: traits that are very frequent in a certain area and infrequent at city level.

#### Implementation

We build a city-level allure which contains traits present in at least 40% of the population. This represents the majority cultural configuration.

We then check if there are traits that are represented in at least the 20% of the population in certain districts. If at least one over-represented trait exists and it is different from the corresponding trait in the majority population, we say that the area has an allure.


## Version 0.2.7
We added a "regeneration" button to test the effects of state sponsored regeneration programmes.
Regeneration is intended in the anglo-saxon, "small state" way. Extra money (outside of the existing Kapital stock = i.e. coming from the public purse) is put in the areas least desirable to investors (= those with the most narrow price-gap) that are also empty and in run-down condition. These areas are brought to the maximum condition and to the mean price of the city. The idea is to check whether this practice can trigger further private investment.

## Version 0.2.6-test
We introduce gaps based on the local maximum price instead of local average

## Version 0.2.5-test
We introduce automatic detection of cultural dynamics. Spotting gentrification, recolonisation, etc is now automatic

## Version 0.2.5-be
### Faster
Parts of the code (similarity, set-gaps) have been made much faster.  Also plot frequency of entropy reduced to every 5 ticks as this was slowing the simulation.

### No centres option
New option of "no centres" added in addiction to mono- policentric.  For comparison with those with centres.

### Better (?) income distribution
Tried a different method of generating a distribution with different gini, but same average income - basically moving one up and one correspondingly down.  Tried a few variations of this - this can take a few seconds to do but seems to work.  More thought on this is needed to make "realistic" income distributions.

### Hisotgrams
Histograms of the distributions of incomes and prices replace previous simple line graph.

### New monitors...
...for occupancy rate and current gini index added.

### similarity for allure slider
now goes up to 1.01!  :-) so that at this setting effectively the allure mechanisms is cut out, for comparison.

## Version 0.2.5
### EMERGING ALLURE
In this version the allure of a district is not imposed from the beginning, instead it is an emergent feature. Allure is initially blank (meaning that the area has no particular connotation), when cultural uniformity reaches a threshold (see update-allure function) the allure is set. This is to reflect the fact that not every neighbourhood has a special connotation in the mind of agents, but only those with a recognizable population (e.g. ONLY HIPPIES LIVE THERE, DON'T GO!)

### Other
In this version we have better code to implement multidimensional culture. Every trait can now have as many values as we want, instead of 2.

### Allure update
Allure is updated every 24 months only if uniformity is high, otherwise the old allure stays.

## Version 0.2.2 - 0.2.3
### Six months interval
Previous change reverted. Investment happens every 6 ticks (for performance pourposes).

### Location location location!
Price gap setting mechanism changed! Now the comparison is made *EITHER* with the Moore neighbourhood as in the original version *OR* with the entire district. The assumption is that, when renovating, the investor will be able to maximize profit charging the mean price of the neighbourhood, if the district is expensive, or the more restrictive Moore neighbourhood. The change has a huge impact, see description.

## Version 0.2.1
### Continous investment.
Unlike the previous version, now property investment happens at every tick. The result is a smoother dynamic.

### Strong neighbourhood preference
Agent value more moving to an alluring neighbourhood. They will accept lower repair state in their preferred location.

## Version 0.2-big
### City size
The city is 1692 patches and 12 neighbourhoods ***** This is now in a separate file ****

### Residential choice

* Residents won't move to a location with condition = 0
* Locations with condition = 0 are given price = 0.0001

## Version 0.2
### Threshold for investment
We now have a price-gap threshold for investment (set in procedure go). The rationale is that the Kapital available is spent in the city only if enough profit can be extracted.

Note that the conservative implementetion of version 0.1 is not as implausible as it seems: there can be cases when the investment is carried out, however little the profit may be. For example if nothing else in the economy produces superior profit. Or for money laundering purposes ;-)

### Neighbourhood selecting process
This is slightly changed to make the agents less choosy when selecting the neighbourhood. They now accept as second best a place 15% below the average condition.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="mabs" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1400"/>
    <enumeratedValueSet variable="Kapital">
      <value value="0.015"/>
      <value value="0.025"/>
      <value value="0.035"/>
      <value value="0.045"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pnas" repetitions="25" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1200"/>
    <enumeratedValueSet variable="Kapital">
      <value value="0.015"/>
      <value value="0.02"/>
      <value value="0.025"/>
      <value value="0.03"/>
      <value value="0.04"/>
      <value value="0.05"/>
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profit-threshold">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immigration-rate">
      <value value="0.012"/>
      <value value="0.045"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gaps">
      <value value="&quot;lnd&quot;"/>
      <value value="&quot;mean&quot;"/>
      <value value="&quot;max&quot;"/>
      <value value="&quot;new&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@

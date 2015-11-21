extensions [gis table]

globals [
  version save-dir save-dir-pics city prices badstate immigration districts file-name-pop disp? disp-freq noncity-postcodes
  downfiltered-districts gentrified-districts file-name-entropy file-name-prices file-name-income areas noncity-areas postcodes
  neighbourhoods-table file-name-validation file-name-world allured-districts firstallure incomes ethni housing-waiting-list
  recolonisation degentrification recreation regentrification file-name-Pendleton lsoas msoas socialhousing surround casestudy
  ]

links-own [time]

turtles-own [mobility-propensity time-here birthday culture income dissonance place-changes time-in-a-slum owner?]

patches-own [
  postcode condition al-longevity condition-previousyear price price-gap months-empty area
  dist centre? social? prob-soc-change lsoa11 lsoa01 msoa01 msoa11 neighbourhood allure last-renovated ward
  ]

breed [citizens citizen]
breed [people person]

to draw-city
  gis:set-drawing-color red
  gis:draw prices 0.2
end

to highlight-city
  ask city [set pcolor green]
  ask city with [count neighbors with [pcolor = black] > 0]  [set pcolor white]
end

to-report neighz
  report neighbors with [member? self city]
end

to setup
  clear-all
  reset-ticks
  set version "0.4.8_LND"
  set disp-freq 5
  set disp? false
  set allured-districts table:make
  set gentrified-districts table:make
  set downfiltered-districts table:make
  set housing-waiting-list table:make
  set save-dir "/home/stefano/Dropbox/urban/results/"
  set save-dir-pics (word save-dir "pics/")
  let gis-data-dir "/home/stefano/ownCloud/GIS/London/Validation/"
  ask patches [set pcolor blue]
  set postcodes gis:load-dataset (word gis-data-dir "London.shp") 
  set prices gis:load-dataset (word gis-data-dir "/2001/Prices_noBelt.shp") 
  set badstate gis:load-dataset (word gis-data-dir "/2001/Condition.shp")
  set incomes gis:load-dataset (word gis-data-dir "/2001/IncomeTenure.shp")
  set ethni gis:load-dataset (word gis-data-dir "/2001/Religion+Ethnicity.shp")
  set socialhousing gis:load-dataset (word gis-data-dir "/2001/SocialHousingDiff.shp")
  gis:set-world-envelope gis:envelope-of prices
  ;gis:set-world-envelope (gis:envelope-union-of (gis:envelope-of prices) (gis:envelope-of slums) (gis:envelope-of badstate)(gis:envelope-of incomes))
  set noncity-postcodes ["W8  4PX" "NW1 4NR" "NW3 1TH" "KT2 7NA" "W1J 9DZ" "SW1A2BJ" "E3  5SN" "E9  5DU" "BR2 6AJ" "BR2 6AH" 
    "E9  7DD" "E20 1AG" "E10 5SG" "E10 5PB" "E10 7QL" "E14 0JJ" "E17 7HG" "SW11 4NJ" "SE10 8XJ" "SW4 9DE" 
    "SW153SA" "W8  6LU" "SW114NJ" "W2  4RU" "W2  2UH" "W2  3XA" "W2  2UH"]
  set noncity-areas ["TW10 5" "E4 8" "E4 7"]
  if Record? [movie-cancel]
  draw-city
  ; if actual-values? [gis:apply-coverage prices "LONDONHIST" price]
  gis:set-coverage-minimum-threshold 0.75
  gis:apply-coverage prices "MSOA11NM" msoa11
  apply-prices
  gis:apply-coverage postcodes "POSTCODE" postcode
  ;gis:apply-coverage slums "LSOA01NM" lsoa01
  gis:apply-coverage badstate "LSOA01NM" lsoa01
  gis:apply-coverage incomes "MSOA" msoa01
  gis:apply-coverage socialhousing "DIFF" prob-soc-change
  ask patches with [gis:intersects? self badstate and count neighbors with [gis:intersects? self badstate] > 1]
  [if is-string? postcode [set-area]]
  set city patches with [
    ; gis:intersects? self badstate and 
    gis:intersects? self prices and 
    is-string? postcode and is-string? msoa11 and
    not member? postcode noncity-postcodes and 
    not member? neighbourhood noncity-areas and
    count neighbors with [is-string? msoa11] > 2 
  ]
  ;if areamax? [set renovation-premium 1.0001]   ;; WE DON'T DO THIS ANYMORE. RENOVATION PREMIUM IS NOW SET IN SET-GAPS.
  ask city [
    set pcolor green
    set social? false
    ]
  adjust-city
  compile-lists
  check-area-sanity
  set-city-condition
  color-patches
  set-centres-and-distances
  generate-population
  ifelse actual-values?
  [populate-city]
  [ask people [
      if any? city with [count citizens-here = 0 and price <= [income] of myself] [
        move-to one-of city with [count citizens-here = 0 and price <= [income] of myself]
      	]
      set breed citizens
      set hidden? false
      ]
  ]
  ask citizens [color-agent]
  set-social
;  set casestudy city with [area = "E20" or area = "E16" or area = "E15"] ; Lower Lea Valley -  Parts of Hackney, Newham, Waltham Forest. 
  let olympicpark one-of city with [area = "E20"]
  ask olympicpark [set casestudy city in-radius 6]
 ; set casestudy city with [lsoa11 = "Salford 024A" or lsoa11 = "Salford 024B" or lsoa11 = "Salford 024C" or lsoa11 = "Salford 024D" or (lsoa11 = "Salford 017B" and neighbourhood = "M6 5")]
 
 ; ask patch 1 13 [set surround city in-radius 5 with [not member? self casestudy]]
 ; set surround city with [area = "M5" or area = "M6" and not member? self casestudy]
  if Record? [movie-start "/home/stefano/model.mov"]
  prepare-data-save
end

to compile-lists
  ;set districts remove-duplicates [ward] of city
  set areas remove-duplicates [area] of city
  set msoas remove-duplicates [msoa11] of city
  ; foreach msoas [if count city with [msoa01 = ?] < 9 [set city city with [msoa01 != ?]]]
end

to check-area-sanity
  foreach areas [
    let these city with [area = ?]
    if count these < 5 [
      set areas remove ? areas
      let where adjacentarea ?
      ask these [
        set area where
        set-neighbourhood
      ]
    ]
  ]
    set districts areas
end

to render-human
  set birthday 0
  ; set color blue
  if ticks = 0 [create-culture]
  reset-mobility-propensity
  set hidden? true
  set size 0.7
end

to generate-population
  create-people N-Agents * 6 [render-human]
  set-default-shape turtles "circle"
  create-ethnic-division
  create-economic-status
end

to populate-city
  create-citizens N-Agents [render-human]
  ask citizens [
    set owner? false   ;; we will turn some of them into owners later
    move-to one-of city with [count citizens-here = 0]]
  generate-area-economic-status
  generate-area-cultural-configuration
end

to generate-area-economic-status
  foreach gis:feature-list-of incomes [
    let averageincome gis:property-value ? "TOT"
    let probowned gis:property-value ? "OWNED"
    let whichplace gis:property-value ? "MSOA" 
    ask citizens-on city with [msoa11 = whichplace] [
      set income random-poisson (averageincome * 54)
      if have-owners? = true [
        if random 1 <= probowned [set owner? true]
      ]
      set hidden? false
    ]
  ]
end

to apply-prices
  foreach gis:feature-list-of prices [
    let wherearewe gis:property-value ? "MSOA11NM"
    let areaprice gis:property-value ? "PRICE01"
    ask patches with [msoa11 = wherearewe] [set price random-poisson areaprice]
  ]
end

to set-social
  foreach gis:feature-list-of socialhousing [
    let whichplace gis:property-value ? "LSOA01NM"
    let tot city with [lsoa01 = whichplace]
    let proportionsocial gis:property-value ? "SOCHOU2001" * count tot
    let sociable tot with [is-owned? = false]
    ifelse count sociable >= proportionsocial
    [ask n-of proportionsocial sociable [set social? true]]
    [ask sociable [set social? true]]
    ask city with [social? = true] [
      set pcolor red
      set condition 0.66
      ]
  ]
end

to-report is-owned?
  if any? citizens-here with [owner?] [report true]
  report false
end

to assign-social-housing 
  let howmany count city with [social? = true and count citizens-here = 0] 
  if howmany > table:length housing-waiting-list [set howmany table:length housing-waiting-list]
  repeat howmany [
    let everybody []
    let candidates []
    foreach table:keys housing-waiting-list [set everybody lput turtle ? everybody]
    ifelse length everybody > 5
    [set candidates sublist everybody 0 4]
    [set candidates everybody]
    let housedperson min-one-of turtle-set candidates [income]
    let locality table:get housing-waiting-list [who] of housedperson
    table:remove housing-waiting-list [who] of housedperson
    ifelse locality != "" and any? city with [social? and not any? citizens-here and area = locality] ; WARNING -- We are using wards only!!
    [move-to-social-housing housedperson locality]
    [move-to-social-housing housedperson ""]
  ]
end

to check-social-residents
  ask citizens-on city with [social?][if time-here >= max-time-in-sh * 12 [seek-place]]
end

to move-to-social-housing [agent locality]
  ask agent [
      set breed citizens
      set time-here 0
      set hidden? false
      ifelse locality = ""
      [move-to one-of city with [social? and not any? citizens-here]]
      [move-to one-of city with [social? and not any? citizens-here and area = locality]]  ; WARNING -- We are using wards only!!
  ]
end

to generate-area-cultural-configuration
  foreach gis:feature-list-of ethni [
    let whichplace gis:property-value ? "LSOA01NM" 
    let totalpop citizens-on city with [lsoa11 = whichplace]
    let muslim round (gis:property-value ? "MUSLIM" * count totalpop)
    let christian round (gis:property-value ? "CHRISTIA" * count totalpop)
    let jewish round (gis:property-value ? "JEWISH" * count totalpop)
    let whites round ((gis:property-value ? "WHITEBRIT" + gis:property-value ? "WHITEIRI") * count totalpop)
    let blacks round ((gis:property-value ? "BLACKAFR" + gis:property-value ? "BLACKCAR" + gis:property-value ? "OTHERBLACK") * count totalpop)
    let subcontinent round ((gis:property-value ? "INDIAN" + gis:property-value ? "PAKISTAN" + gis:property-value ? "BANGLADE") * count totalpop) 
    let chinese round (gis:property-value ? "CHINESE" * count totalpop)
    ; show (word "Area: " whichplace " - Population: " totalpop "Christians: " christian "- Muslims: " muslim " - Jew: " jewish " - Whites: " whites " - Blacks: " blacks )
    ask n-of whites totalpop with [item 0 culture = 5] [set culture replace-item 0 culture 0]
    ask n-of blacks totalpop with [item 0 culture = 5] [set culture replace-item 0 culture 1]
    ask n-of subcontinent totalpop with [item 0 culture = 5] [set culture replace-item 0 culture 2]
    ask n-of chinese totalpop with [item 0 culture = 5] [set culture replace-item 0 culture 3]
    ask n-of christian totalpop with [item 1 culture = 5] [set culture replace-item 1 culture 0]
    ask n-of muslim totalpop with [item 1 culture = 5] [set culture replace-item 1 culture 1]
    ask n-of jewish totalpop with [item 1 culture = 5] [set culture replace-item 1 culture 2]
    ;; ask n-of TOBEDECIDED citizens-on city with [item 1 culture = 5 and lsoa11 = whichplace] [set item 1 culture 3]
    if any? totalpop with [item 0 culture = 5 or item 1 culture = 5] [
      ask totalpop with [item 0 culture = 5 or item 1 culture = 5] [   ; those who have not been allocated yet
        if item 0 culture = 5 [set culture replace-item 0 culture random traits]
        if item 1 culture = 5 [set culture replace-item 1 culture random traits]
      ]
    ]
  ]
end

to set-centres-and-distances
  if kind = "policentric" [
    foreach areas [
      let x 0
      let y 0
      set x (([pxcor] of max-one-of city with [area = ?] [pxcor] - [pxcor] of min-one-of city with [area = ?] [pxcor]) / 2) + [pxcor] of min-one-of city with [area = ?] [pxcor]
      set y (([pycor] of max-one-of city with [area = ?] [pycor] - [pycor] of min-one-of city with [area = ?] [pycor]) / 2) + [pycor] of min-one-of city with [area = ?] [pycor]
      if member? patch x y city [
        ask patch x y [
          if not any? neighbors with [not member? self city][
            set centre? true
            set pcolor blue
          ]
        ]
      ]
    ]
  ]
  ask city [
    let centre min-one-of city with [MSOA11 = "City of London 001"] [distance myself] ;; monocentric city
    if kind = "policentric"
    [set centre min-one-of city with [centre? = true] [distance myself]]  ;; policentric city
    set dist distance centre
    ]
end

to check-new-allure    ;; This estabilishes whether we need to create a new allure 
  foreach districts [
    if [allure] of one-of city with [area = ?] = 0 [
      if (uniformity ? >= uniformity-for-allure and occupancy ? > 0.3) [
        update-allure ?
        table:put allured-districts ? (list (mean [income] of citizens-on city with [area = ?]) (mean [price] of city with [area = ?]) (occupancy ?))
        ;; We store a table with uniform districts and median income, to spot recolonisation
        if firstallure = 0 [set firstallure ticks]
        ask city with [area = ?][set al-longevity al-longevity + 1]
      ]
    ]
  ]
end

to adjust-city
  ask city [
    set centre? false
    ifelse actual-values? [
      if not is-number? price or not (price > 10000) [
        ifelse any? neighbors with [is-number? price and price > 10000]
          [set price mean [price] of neighbors with [is-number? price and price > 10000]]
          [ifelse any? city with [postcode = [postcode] of myself and is-number? price and price > 10000]
            [set price mean [price] of city with [postcode = [postcode] of myself and is-number? price and price > 10000]]
            [ifelse any? city with [msoa11 = [msoa11] of myself and is-number? price and price > 100]
                [set price mean [price] of city with [msoa11 = [msoa11] of myself and is-number? price and price > 10000]]
                [set price mean [price] of city with [area = [area] of myself and is-number? price and price > 10000]]
              ]
          ]
      ]
    ]
    [set price random-float 1]
    ;adjust-wards
    set months-empty 0
  ]
end

to build-social-housing [howmany]
  let sofar 0
  let zerop min [price] of city
  let zeroc min [condition] of city
  let avg mean [price] of city with [count citizens-here > 0] 
  let firstsocial nobody
  let worst city with [not any? citizens-here and price <= zerop and condition <= zeroc]
  ifelse any? worst 
  [set firstsocial min-one-of worst [price-gap]] 
  [set firstsocial max-one-of city [months-empty]] 
  ask firstsocial [
    set social? true
    set price avg / 2
    set condition 0.95 
    set sofar sofar + 1
    while [sofar < howmany] [
      ask one-of city in-radius 4 with [not social?] [
        if not any? citizens-here [
          set social? true
          set pcolor red
          set price avg / 2
          set condition 0.66
          set sofar sofar + 1
        ]
      ]
    ]
  ]
end


;to adjust-wards
;  if is-number? ward or length ward < 2 [
;    set ward [ward] of one-of neighbors with [not is-number? ward]
;  ]
;    if neighbourhood = "M22 5" [set ward "Woodhouse Park"]
;    if postcode = "M22 4QR" [set ward "Sharston"]
;    if ward = "" [set ward "Unknown Place"]
;    if ward = "Timperley" [set ward "Village"]
;    if ward = "Chadderton South" [set ward "Moston"]
;    if ward = "Broadheath" [set ward "Brooklands"]
;end

to set-area
  ifelse item 2 postcode = " "
  [set area substring postcode 0 2]
  [ifelse item 3 postcode = " " 
    [set area substring postcode 0 3]
    [set area substring postcode 0 4]
  ]
  set-neighbourhood
end

to set-neighbourhood
  set neighbourhood (word area " " item 4 postcode)
end

to set-city-condition
  ask city [set condition 0]
  ifelse actual-values? 
  [set-actual-condition]
  [ask city [
      set condition price - 0.15
      if condition < 0 [set condition 0.05]
   ]
 ]
end

to set-actual-condition
  foreach gis:feature-list-of badstate [   ;; first we create the % of slums area by area
    let averageslum (gis:property-value ? "SLUMS") 
    let belowaverage (gis:property-value ? "BADSTATE") 
    let placename gis:property-value ? "LSOA01NM"
    let totdistrict count city with [lsoa01 = placename]
    if totdistrict > 0 [
      ask n-of (round (averageslum * totdistrict)) city with [lsoa01 = placename] [
        set condition random-float 0.15
      ]
      ask n-of (round (belowaverage * totdistrict)) city with [lsoa01 = placename and condition = 0]
      [set condition 0.15 + random-float 0.35]
    ]
  ]
  ask city with [condition = 0] [set condition 0.50 + random-float 0.50]   ;; the rest of the patches is somewhere between 0.50 and 1
end


to create-culture
  set culture n-values traits [random values]
  set culture replace-item 0 culture 5
  set culture replace-item 1 culture 5
end

to create-ethnic-division
  let totalpop count people
  ask n-of (round 0.87 * totalpop) people [set culture replace-item 0 culture 0]
  ask n-of (round 0.03 * totalpop) people with [item 0 culture = 5] [set culture replace-item 0 culture 1]
  ask n-of (round 0.07 * totalpop) people with [item 0 culture = 5] [
    set culture replace-item 0 culture 2
    set culture replace-item 1 culture 1
    ]
  ask n-of (round 0.01 * totalpop) people with [item 0 culture = 5] [set culture replace-item 0 culture 3]
  ask people with [item 0 culture = 5] [set culture replace-item 0 culture random traits]
end

to create-economic-status
  ifelse actual-values?    
  [
    ask people [set income 0]         ;; taken from https://en.wikipedia.org/wiki/Income_in_the_United_Kingdom#Wealth
    let totalpop count people
    ask n-of (round 0.01 * totalpop) people with [income = 0] [set income 688000 + random-poisson 500000]
    ask n-of (round 0.02 * totalpop) people with [income = 0] [set income 460000 + random-poisson 228000]
    ask n-of (round 0.05 * totalpop) people with [income = 0] [set income 270000 + random-poisson 190000]
    ask n-of (round 0.1 * totalpop) people  with [income = 0] [set income 176000 + random-poisson 80000 ]
    ask n-of (round 0.25 * totalpop) people with [income = 0] [set income 76000 + random-poisson 100000 ]
    ask n-of (round 0.5 * totalpop) people  with [income = 0] [set income 35000 + random-poisson 40000]
    ask people with [income = 0] [set income 10000 + random-poisson 25000]
    ]
  [ask people [set income random-float 1]
   if random-income? = false [create-skewed-economic-status]
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
     ; show (word med " " gini people)
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
    ;  show (word med " " gini people)
    ]
  ]
end 

to-report gini [group]
;; Gini calculation code borrowed from the 'wealth distribution' model.
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

to-report safe-division [a b]
  if a = 0 or b = 0 [report 0]
  report a / b
end

to-report uniformity [where]
  let common 0
  let thispeople nobody
  ifelse is-patch-set? where
  [set thispeople citizens-on where]
  [set thispeople citizens-on city with [ward = where]]
  let pairs (count thispeople * (count thispeople - 1)) / 2
  ask thispeople [
    ask other thispeople [
      set common common + (similarity self myself / traits)
    ]
  ]
  report safe-division (safe-division common 2) pairs
end

to-report occupancy [place]
  let total city with [area = place]
  let occupied count total with [count citizens-here > 0]
  report occupied / count total
end

to-report non-social-occupancy [place]
  let total city with [area = place and social? = false]
  let occupied count total with [count citizens-here > 0]
  report occupied / count total
end

to update-allure [district]
    if any? citizens-on city with [ward = district] [
      let these citizens-on city with [ward = district]
      let newallure n-values traits [0]
      let trt 0
      while [trt <= traits - 1] [
        let thistrait one-of modes [item trt culture] of these
        set newallure replace-item trt newallure thistrait
        set trt trt + 1
      ]
      ask city with [ward = district] [set allure newallure]
    ]
end

to color-agent
  if income > median [income] of citizens * 2 [set color green]
  if income < median [income] of citizens * 2 and income > median [income] of citizens [set color green + 4]
  if income <= median [income] of citizens and income >= median [income] of citizens / 2 [set color violet + 2]
  if income < median [income] of citizens / 2 [set color violet - 1]
end

to color-patches
  ask city with [social? = false] [
    if condition >= 0.75 [set pcolor white]
    if condition < 0.75 and condition > 0.50 [set pcolor grey + 2]
    if condition <= 0.50 and condition > 0.25 [set pcolor grey - 2]
    if condition <= 0.25 [set pcolor black]
  ]
end

to-report similarity [a b]
  let sim 0
  ifelse is-turtle? b [
    (foreach ([culture] of a) ([culture] of b)  
      [if ?1 = ?2 [set sim sim + 1] ] )
  ]
  [
    (foreach ([culture] of a) ([allure] of b)     ;; in this case b is a patch
      [if ?1 = ?2 [set sim sim + 1] ] )
  ]
  report sim
end

to go
  ask city [
    ifelse unified? = true 
    [set-gaps-unified]
    [set-gaps-lnd]
    if social? = false [decay]
    update-emptiness
    ifelse social?
    [
      set price median [price] of city with [neighbourhood = [neighbourhood] of self] * 0.66
      reverse-social
      ]
    [update-price]
  ]
  if ticks < 1000 and any? city with [allure = 0] [check-new-allure]
  if ticks mod 24 = 0 and table:length allured-districts > 0 [check-existing-allure]
  update-links
  update-dissonance
  update-propensity
  interact
  ask citizens [
    set time-here ticks - birthday
   ; set size 0.01 * time-here
   ; if size >= 1.3 [set size 1.3]
    if decide-moving [seek-place]
  ]
  color-patches
  if ticks > 0 and ticks mod 6 = 0 [
    do-business
    if inmigration = true [inmigrate]
    if (any? city with [social? = true and count citizens-here = 0]) and (table:length housing-waiting-list > 0) [assign-social-housing]
    if any? city with [social? = true][check-social-residents]
  ]
  ask citizens [color-agent]
  tick
  ;save-data-Pend
  if ticks mod 12 = 0 [
    if write-csv? [save-data]
    if Record? [movie-grab-view]
  ]
  if ticks = 84 and credit-crunch = true [set Kapital Kapital * 0.75]
  if ticks = 132 and Olympics? = true [OLYMPICS]
  if ticks = 131 and credit-crunch = true [set Kapital Kapital * 1.35]
  if ticks = duration [
    if Record? [movie-close]
    save-data
    stop
  ]
end

to check-existing-allure
  foreach table:keys allured-districts [
    ifelse uniformity ? >= uniformity-for-allure [
      ask city with [ward = ?][set al-longevity al-longevity + 24]
      update-allure ?
      if table:has-key? gentrified-districts ? [determine-super-phenomenon ? 0]
      if table:has-key? downfiltered-districts ? [determine-super-phenomenon ? 1]
    ]
    [
      if not table:has-key? gentrified-districts ? and not table:has-key? downfiltered-districts ? and [al-longevity] of one-of city with [ward = ?] > 24
      [determine-phenomenon ?]
    ]
  ]
end


to determine-phenomenon [place]
  ifelse mean [income] of citizens-on city with [ward = place] > item 0 table:get allured-districts place
    [table:put gentrified-districts place (list mean [income] of citizens-on city with [ward = place] mean [price] of city with [ward = place] occupancy place)]
    [table:put downfiltered-districts place (list mean [income] of citizens-on city with [ward = place] mean [price] of city with [ward = place] occupancy place)]
end

to determine-super-phenomenon [district case]  ;; when a place lost than regained uniformity. What's happening???
  ifelse case = 0  [   ;; in this case originally gentrification dissolved uniformity
    ifelse mean [income] of citizens-on city with [ward = district] >= (item 0 table:get gentrified-districts district - 0.1) and mean [price] of city with [ward = district] >= (item 1 table:get gentrified-districts district - 0.1)
    [set recolonisation recolonisation + 1]
    [set degentrification degentrification + 1]
  ] 
  [ ; here originally downfiltering dissolved uniformity
    ifelse mean [income] of citizens-on city with [ward = district] <= (item 0 table:get downfiltered-districts district + 0.1)
    [set recreation recreation + 1]
    [set regentrification regentrification + 1]
  ]
end

to do-business ;; Renovation happens twice a year according to available capital.
  let howmany (Kapital * count city) / 2
  let goodgap city with [price-gap >= (price * profit-threshold) and condition <= 0.75] 
  if count goodgap < howmany [set howmany count goodgap]
  ask max-n-of howmany goodgap [price-gap] [renovate]
;  ask max-n-of 9 city with [social?] [price-gap] [   ;; un cazzo di numero magico in mezzo al modello senza nessuna giustificazione, nessun link, niente.
;    set social? false                                ;; Ti devono mangiare i cani. La fine che farai te la meriti fino all'ultimo  
;    renovate
;  ]
end

to inmigrate ;; Immigration happens twice a year (yeah, i know..)
  let howmany 1 + ((count citizens * immigration-rate) / 2)
  ask n-of howmany people [
    render-human
    ;if actual-values? [set income 10000 + random 200000]
    if table:has-key? housing-waiting-list who [table:remove housing-waiting-list who]
    set breed citizens
    set hidden? false
    seek-place
    ]
end

to leave-city
  ask my-links [die]
  set breed people
  set hidden? true
end

to enter-housing-list [agent place]
  ;; set housing-waiting-list lput (list(agent)(place)) housing-waiting-list 
  table:put housing-waiting-list [who] of agent place
  ask agent [
    set breed people
    set hidden? true
    ]
end

to-report decide-moving
  let param income
  if actual-values? [set param income * Credit]
  if ([price] of patch-here > param and [social?] of patch-here = FALSE and owner? = FALSE) or (random-float 1 < mobility-propensity) [
    set place-changes place-changes + 1
    report true
  ]
  report false
end

to seek-place
;; When seeking a spot we consider vacant affordable places close to the (city or district) centre and with a pleasant cultural mix.
;; This is in line with Jackson et al. 2008, although they have a Schelling-like ethnic (not cultural) mix.
;; In this version agents only evaluate the CULTURAL ALLURE of a district, not the STATUS. 
;; If we are to finegrain the model we could also include status in the decision process.
  let howmuch income
  if actual-values? [set howmuch income * Credit]
  ifelse PULL? and any? city with [allure != 0]
  [
    let where set-place
    ifelse where != "" [
      ifelse strong-neighbourhood?
      [relocate-to where howmuch]
      [weak-relocate-to where howmuch]
    ][relocate howmuch]
  ]
  [relocate howmuch]
end

to-report set-place
  let best_ftr traits * (similarity-threshold * 2)
  let bestdistrict ""
  let trythese []
  foreach districts [if is-list? [allure] of one-of city with [ward = ?] [set trythese fput ? trythese]]
  foreach trythese [
    let this_similarity 0
    set this_similarity similarity self one-of city with [ward = ?]
    if this_similarity >= best_ftr [
      	set best_ftr this_similarity
      	set bestdistrict ?
      	]
      ]
    report bestdistrict
end

to relocate [will]
  let baseline city with [(price <= will) and (count citizens-here = 0) and (condition > 0) and (social? = false)]
  ifelse any? baseline [
    let testbed n-of (count city / 10) city
    let condi mean [condition] of testbed
    let secondbest baseline with [(price <= will) and (count citizens-here = 0) and (condition >= (condi - (condi * 0.15 )))]  ;; if we can't find a place we like then we move to one we can afford
    ifelse any? secondbest 
    [move-to min-one-of secondbest [dist]]
    [move-to min-one-of baseline [dist]]
  ][enter-housing-list self ""]  ;; if no place exists we apply for social housing
end


to relocate-to [place will]
  let baseline city with [(price <= will) and (count citizens-here = 0) and (condition > 0) and (social? = false)] ;Add to prevent people from moving to decrepit loc:; and (condition > 0)
  ifelse any? baseline [
    let testbed n-of (count city / 10) city
    let condi mean [condition] of testbed
    let secondbest patch-set []
    let ideal baseline with [(area = place) and (condition >= (condi - (condi * 0.15 )))]
    set ideal baseline with [(ward = place) and (condition >= (condi - (condi * 0.15 )))]
    ifelse any? ideal
      [move-to min-one-of ideal [dist]]
      [
        let acceptable baseline with [condition >= (condi - (condi / 2 ))]
        set secondbest acceptable with [ward = place]
        ifelse any? secondbest
        [move-to min-one-of secondbest [dist]]
        [ifelse any? acceptable
          [move-to min-one-of acceptable [dist]]
          [move-to min-one-of baseline [dist]]
        ]
      ]
  ]
  [enter-housing-list self place]
end

to weak-relocate-to [place will]
    let ideal city with [(price <= will) and (count citizens-here = 0) and (social? = false) and (ward = place) and (condition >= (mean [condition] of city - (mean [condition] of city * 0.15 )))]
    ifelse any? ideal
    [move-to min-one-of ideal [dist]]
    [let secondbest city with [(price <= will) and (count citizens-here = 0) and (condition >= (mean [condition] of city - (mean [condition] of city * 0.15 )))]  ;; if we can't find a place we like then we move to one we can afford
      ifelse any? secondbest 
      [move-to min-one-of secondbest [dist]]
      [let thirdbest city with [(price <= will) and (count citizens-here = 0)  ] ;; Uncomment the following to prevent people from moving in decrepit locations ;and (condition > 0)
       ifelse any? thirdbest [move-to min-one-of thirdbest [dist]] [leave-city]  ;; if no place exists we leave the city.
      ]
    ]
end

to set-gaps-lnd
  let whichprice 0
  let neigh-price 0
  let areaprice 0
  let sample []
  ifelse unit = "area"
  [set sample city with [msoa11 = [msoa11] of myself]]
  [set sample city in-radius 5]
  let renovation-premium 1 + premium
  ifelse areamax?
  [set areaprice max [price] of sample]
  [set areaprice mean [price] of sample]
  set whichprice areaprice * renovation-premium
  ifelse whichprice > price
    [
      ifelse any? citizens-here with [owner? = false and (income * credit) < whichprice]
      [set price-gap (whichprice - (price + (resident-removal-cost * price)))]   ;; we anticipate whether we will have to kick someone out
      [set price-gap (whichprice - price)]
    ]
    [set price-gap 0]
end

to set-gaps-unified
  let whichprice 0
  let neigh-price 0
  let areaprice 0
  let sample city with [area = [area] of myself and months-empty < tolerable-vacancy]
  let goodneigh neighz with [months-empty < tolerable-vacancy]
  let density non-social-occupancy area
  let renovation-premium 1 + random premium
  ifelse density >= 0.8
  [set areaprice max [price] of sample
    ifelse count goodneigh = 0
    [set neigh-price median [price] of neighz * 0.8]
    [set neigh-price max [price] of goodneigh]
   ]
  [
    ifelse count sample > 0
      [set areaprice mean [price] of sample]
      [set areaprice mean [price] of city with [area = [area] of myself] * 0.80]
    ifelse count goodneigh > 0 
      [set neigh-price mean [price] of goodneigh]
      [set neigh-price mean [price] of neighz * 0.8]
  ]
  ifelse neigh-price > areaprice
  [set whichprice neigh-price * renovation-premium]
  [set whichprice areaprice * renovation-premium]
end

to renovate
  set price price + price-gap
  set condition 0.95
  set last-renovated ticks
end

to decay
  let depr monthly-decay
  let time ticks - last-renovated
  if time < 48 [set depr 0]
  if time >= 48 and time <= 60 [set depr depr / 2]
  if time >= 120 and time <= 240 [set depr depr * 2]
  if not any? citizens-here [set depr depr * 1.20]
  ifelse condition - depr <= 0
    [set condition 0]
    [set condition condition - depr]
end

to update-price   ;; Price reconsideration happens every MONTH 
  let depr annual-depreciation-rate / 12   ;;; Price "naturally" decays 2%/year 
  let time ticks - last-renovated
  if time <= 24 [set depr 0]
  if time > 24 and time <= 60 [set depr depr / 2]
  if time >= 120 and time <= 240 [set depr depr * 2]
  if months-empty > tolerable-vacancy [set depr depr * 2]
  set price (price - (price * depr))
end

to update-emptiness
  ifelse count citizens-here = 0 
  [set months-empty months-empty + 1]
  [set months-empty 0]
end

to update-links
  ask links [    ;; First we check existing links. If the agents are still neighbours we reinforce the relationship, if not we weaken it.
    let stillclose false
    ask one-of both-ends [if ward = [ward] of other-end or distance other-end <= 2 [set stillclose true] ]
    ifelse stillclose
    [if time < 12 [set time time + 1]]
    [
      set time time - 1
      if time <= 0 [die]
    ]
  ]
  ask citizens [    ;; Then we create new links for neighbours that still don't have one (i.e. new neighbours)
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

to update-dissonance
  ask citizens [
    if PUSH? [
      if count citizens-on neighbors > 0 [
        let maxsimilarity count citizens-on neighbors * traits
        let simil 0
        ask citizens-on neighbors [set simil simil + similarity self myself]
        ifelse (simil / maxsimilarity) <= similarity-threshold
        [set dissonance dissonance + 1]
        [set dissonance 0]
      ]
    ]
    ifelse [condition] of patch-here < 0.15
    [set time-in-a-slum time-in-a-slum + 1]
    [set time-in-a-slum 0]
  ]
end

to update-propensity
  ask citizens [   ;;;;;; there was a serious bug here
    if time-in-a-slum = 0 and dissonance <= tolerable-dissonance [reset-mobility-propensity]
    if ((time-in-a-slum > 12) and ((income * credit) > [price] of patch-here * 1.20))
    or (median [condition] of neighz <= 0.15) [set mobility-propensity mobility-propensity * 1.50]
    if dissonance > tolerable-dissonance [
      set mobility-propensity mobility-propensity * 1.50
      if random-float 1 < 0.05 [mutate]
      ]
    if mobility-propensity > 1 [set mobility-propensity 1]
  ]
end

to reverse-social
  let timespan 10
  ifelse prob-soc-change < 0 ; prob-soc-change is over 10 years, so we have a fixed probability every month
  [if random 1 <= prob-soc-change / timespan * 12 [set social? false]] ;
  [if random 1 <= prob-soc-change / timespan * 12 [set social? true]]
end

;; The idea here is that prolonged co-location leads to cultural mixing. 
;; We need each household to keep track of how long they have been neighbours with each other 
to interact
  ask links with [time > 6] [
    let a item 0 sort both-ends
    let b item 1 sort both-ends
      if similarity a b < traits [
        let whichone 2 + random (traits - 2)  ; traits 0 (ethnicity) and 1 (religion) never change.
        if item whichone [culture] of a != item whichone [culture] of b [
          ifelse random-float 1 <= 0.5
           [ask b [set culture replace-item whichone culture item whichone [culture] of a]]
           [ask a [set culture replace-item whichone culture item whichone [culture] of b]]
        ]
      ]
  ]
end

;to boost-centre
;  ask min-one-of 
;end

to OLYMPICS    ;;; Questo e' da rivedere.......
  ask min-n-of (count casestudy / 2) casestudy [distance min-one-of city with [MSOA11 = "City of London 001"] [distance myself] ] [
    ifelse social? [
      set social? false
      set price 315000 + random 150000
    ][set price price * 1.50]
    set condition 0.95
    ]
end

to mutate
  let where [neighbourhood] of patch-here
  let trait (2 + random (traits - 2))
  let most one-of modes [item trait culture] of citizens-on city with [neighbourhood = where]
  set culture replace-item trait culture most
end

to-report caseprice
  if ticks > 1 [report median [price] of casestudy]
  report 0
end

to-report surroundprice
  if ticks > 1 [report median [price] of surround]
  report 0
end

to-report cityprice
  if ticks > 1 [report median [price] of city]
  report 0
end

to-report surroundincome
  if ticks > 1 [report median [income] of citizens-on surround]
  report 0
end

to-report caseincome
  if ticks > 1 [report median [income] of citizens-on casestudy]
  report 0
end

to-report cityincome
  if ticks > 1 [report median [income] of citizens]
  report 0
end

to-report cityUniformity
if ticks > 1 [report uniformity city]
report 0
end

to-report caseUniformity
if ticks > 1 [report uniformity casestudy]
report 0
end

to-report surroundUniformity
if ticks > 1 [report uniformity surround]
report 0
end

to-report adjacentmsoa [msoa]
  let where min-one-of city with [any? citizens-here] [distance one-of patches with [msoa11 = msoa]]
  report [msoa11] of where
end

to-report adjacentarea [place]
  let where min-one-of city with [count city with [area = [area] of myself] >= 5] [distance one-of patches with [area = place]]
  report [area] of where
end


to prepare-data-save
  ;let push ""
  ;let pull ""
  let gap-type "AREA"
  if area-gaps? = false [set gap-type "LOCAL"]
  let gap-value "MEAN"
  if areamax? [set gap-value "MAX"]
  let run-number 0
  ;if PUSH? [set push "PUSH"]
  ;if PULL? [set pull "PULL"]
  ;ifelse actual-values? 
  ;[set actual "ACTUAL"]
  ;[set actual "RANDOM"]
  ;if behaviorspace-run-number != 0 [set run-number behaviorspace-run-number]
  ;set file-name-entropy (word save-dir "gentax-" version "-UNIFORMITY-" regenerate? "-I-" immigration-rate "-" gap-type "-" gap-value "-" kind "-K" Kapital ".csv")
  ;set file-name-pop (word save-dir "gentax-" version "-POPULATION-" regenerate? "-I-" immigration-rate "-" gap-type "-" gap-value "-" kind "-K" Kapital ".csv")
  ;set file-name-prices (word save-dir "gentax-" version "-PRICES-" regenerate? "-I-" immigration-rate "-" gap-type "-" gap-value "-" kind "-K" Kapital ".csv")
  set file-name-validation (word save-dir "gentax-" version "-VALIDATION-" "-I-" immigration-rate "-" unified? "-" gap-value "-" kind "-K" Kapital ".csv")
  set file-name-income (word save-dir "gentax-" version "-INCOME-" olympics? "-I-" immigration-rate "-" gap-type  "-" gap-value "-" kind "-K" Kapital ".csv")
  ;set file-name-Pendleton (word save-dir "gentax-" version "-REGENERATION-" regenerate? "-I-" immigration-rate "-" gap-type  "-" gap-value "-" kind "-K" Kapital ".csv")
  ;file-open file-name-entropy
  ;file-write "ticks;" 
  ;foreach districts [file-write (word ? ";")]
  ;file-print ""
  file-open file-name-validation
  file-write "ticks;"
  foreach msoas [file-type (word ? ";")]
  file-print "" 
  ;file-open file-name-prices
  ;file-write "ticks;"
  ;foreach districts [file-write (word ? ";")] 
  ;file-print ""
  ;file-open file-name-Pendleton
  ;file-write "ticks;areaPrice;surroundPrice;cityPrice;areaIncome;surroundIncome;cityIncome;cityUniformity;caseUniformity;surroundUniformity"
  ;file-print ""
  ;file-open file-name-income
  ;file-write "ticks;" 
  ;foreach msoas [file-write (word ? ";")]
  ;file-print ""
  file-close-all
end

to save-data-Pend
  file-open file-name-Pendleton
  file-print (word ticks ";" caseprice ";" surroundprice ";" cityprice ";" caseincome ";" surroundincome ";" cityincome ";" cityUniformity ";" caseUniformity ";" surroundUniformity)
  file-close
end
  
to save-data
  let gap-type "AREA"
  if area-gaps? = false [set gap-type "LOCAL"]
  let gap-value "MEAN"
  if areamax? [set gap-value "MAX"]
  ;file-open file-name-entropy
  ;file-write (word ticks ";")
  ;foreach districts [file-write (word uniformity ? ";")]
  ;file-print " "
  file-open file-name-validation
  file-write (word ticks ";")
  foreach msoas [file-type (word median [price] of city with [msoa11 = ? and social? = false] ";")]
  file-print " " 
  ;file-open file-name-prices
  ;file-write (word ticks ";")
  ;foreach districts [file-write (word median [price] of city with [ward = ?] ";")]
  ;file-print " "
  file-open file-name-income
  file-write (word ticks ";")
  foreach msoas [ifelse any? citizens-on city with [msoa11 = ?] 
    [file-write (word median [income] of citizens-on city with [msoa11 = ?] ";")]
    [
      let neighbouring adjacentmsoa ? 
      file-write (word median [income] of citizens-on city with [msoa11 = neighbouring] ";")
    ]
  ]
  ;file-print " "
  file-close-all
  set file-name-world (word "gentax-" version "-world-k" Kapital "-" unified? "-" gap-value "-I-" immigration-rate "-" kind "-" olympics? "-" ticks ".png")
  export-view (word save-dir-pics file-name-world)
end

to plot-ent [dis]
  if disp? [repeat disp-freq [plot uniformity dis]]
end

to-report medianincome [place]
  ifelse any? citizens-on city with [ward = place] [
    report median [income] of citizens-on city with [ward = place]
  ][report 0]
end
@#$#@#$#@
GRAPHICS-WINDOW
-39
10
1341
1071
80
60
8.5124
1
5
1
1
1
0
0
0
1
-80
80
-60
60
1
1
1
Months
30.0

BUTTON
1
1094
56
1127
setup
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
58
1094
113
1127
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

SLIDER
8
1347
151
1380
monthly-decay
monthly-decay
0
0.02
0.0015
0.0001
1
NIL
HORIZONTAL

SLIDER
840
1162
993
1195
tolerable-vacancy
tolerable-vacancy
0
24
9
1
1
months
HORIZONTAL

SLIDER
117
1105
270
1138
prob-move
prob-move
0
0.5
0.005
0.0001
1
NIL
HORIZONTAL

SLIDER
278
1104
457
1137
traits
traits
0
10
10
1
1
NIL
HORIZONTAL

SLIDER
277
1139
458
1172
values
values
0
10
4
1
1
NIL
HORIZONTAL

TEXTBOX
282
1086
342
1104
CULTURE
12
0.0
1

SLIDER
117
1139
270
1172
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
840
1200
992
1233
init-gini
init-gini
0
1
0.36
0.001
1
NIL
HORIZONTAL

SLIDER
0
1134
107
1167
N-Agents
N-Agents
0
count patches
6564
1
1
NIL
HORIZONTAL

SWITCH
663
1094
810
1127
random-income?
random-income?
1
1
-1000

SLIDER
839
1091
993
1124
Kapital
Kapital
0
0.2
0.1
0.001
1
NIL
HORIZONTAL

SWITCH
117
1173
231
1206
inmigration
inmigration
0
1
-1000

SLIDER
464
1099
646
1132
tolerable-dissonance
tolerable-dissonance
0
24
6
1
1
months
HORIZONTAL

SLIDER
464
1137
647
1170
similarity-threshold
similarity-threshold
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
841
1237
990
1270
profit-threshold
profit-threshold
0
0.5
0.3
0.001
1
NIL
HORIZONTAL

BUTTON
469
1175
607
1208
Display wards
ask city with [allure != 0][set pcolor yellow]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
278
1213
458
1246
strong-neighbourhood?
strong-neighbourhood?
0
1
-1000

SWITCH
370
1175
460
1208
PULL?
PULL?
0
1
-1000

SWITCH
277
1174
367
1207
PUSH?
PUSH?
0
1
-1000

TEXTBOX
837
1073
987
1091
ECONOMY
12
0.0
1

TEXTBOX
119
1087
199
1105
POPULATION
12
0.0
1

SWITCH
0
1204
105
1237
Record?
Record?
1
1
-1000

SWITCH
0
1169
105
1202
write-csv?
write-csv?
0
1
-1000

TEXTBOX
9
1248
159
1266
CITY
12
0.0
1

SLIDER
839
1126
993
1159
Credit
Credit
0
15
8
1
1
NIL
HORIZONTAL

SLIDER
662
1131
834
1164
premium
premium
0
2
0.25
0.001
1
NIL
HORIZONTAL

CHOOSER
8
1265
146
1310
kind
kind
"monocentric" "policentric"
0

SLIDER
307
1268
451
1301
uniformity-for-allure
uniformity-for-allure
0
1
0.6
0.01
1
NIL
HORIZONTAL

BUTTON
469
1211
607
1244
Undisplay wards
color-patches
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
8
1313
147
1346
actual-values?
actual-values?
0
1
-1000

CHOOSER
161
1266
307
1311
unit
unit
"area" "local"
1

SWITCH
664
1203
779
1236
areamax?
areamax?
1
1
-1000

SWITCH
665
1239
779
1272
area-gaps?
area-gaps?
0
1
-1000

SLIDER
650
1317
803
1350
resident-removal-cost
resident-removal-cost
0
0.5
0.065
0.001
1
NIL
HORIZONTAL

SLIDER
161
1314
301
1347
annual-depreciation-rate
annual-depreciation-rate
0
0.2
0.014
0.001
1
NIL
HORIZONTAL

BUTTON
470
1250
536
1283
RUN!
setup\nrepeat duration [go]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
117
1207
271
1240
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
160
1351
300
1384
max-time-in-sh
max-time-in-sh
0
70
50
1
1
NIL
HORIZONTAL

SWITCH
841
1274
960
1307
Olympics?
Olympics?
1
1
-1000

SWITCH
839
1309
960
1342
credit-crunch
credit-crunch
0
1
-1000

INPUTBOX
541
1250
610
1310
duration
156
1
0
Number

SWITCH
664
1274
769
1307
unified?
unified?
1
1
-1000

TEXTBOX
668
1179
708
1197
GAPS
12
0.0
1

SWITCH
841
1344
961
1377
have-owners?
have-owners?
0
1
-1000

@#$#@#$#@
# Introduction

*Gentrification meets Axelrod meets Schelling.*

This is a city-scale residential mobiliy model with benefits. It couples residential choice with investment/disinvestment and cultural dynamics. Agents are created with a unique culture + income level and move throughout the city in search of a location that, in order of importance, is:

* affordable 
* in relatively good condition 
* as close as possible to the centre of the city  
* located in a culturally appealing neighbourhood (cultural pull). 

Dwellings (individual patches) have a price and a mainteniance condition. They progressively decay in their condition and, accordingly, in their asking price. 

If sufficient Kapital is available, renovation is carried out on those locations that present the wider "price-gap" with the neighbouring properties, as proposed in most computational implementations of Neil Smith's (RIP) rent-gap theory. 
After renovation a property is reset to the highest possible condition and is able to charge a price equal to the average of neighbouring properties + a 15% premium.

# Model detail
##Agent model
The agent's **culture** is modelled as a n-th dimensional binary string (currently n=10) of "traits", as in the great tradition of "string culture" (Axelrod, etc.)
The agent's **income level** is set at random, normalized to the interval 0-1. No "social mobility" exists: income is a fixed attribute and never changes.
Agents are also created with a **mobility-propensity** parameter, which is very low in the beginning (the initial probability to move is poisson distributed in the population centred on 0.001/month).

### Micro-level cultural dynamics
Long time neighbouring agents with at least one common trait are more likely to interact and exchange traits, thus rendering the respective cultural strings more similar. A **cultural cognitive dissonance** parameter implements a concept proposed by Portugali (1996): this is, roughly, the frustration of being surrounded by too many culturally distant agents. Yes, it's Schelling in other terms. 

### Residential mobility
One agent's mobility propensity attribute is increased when: 

* Excessive time is spent in a dwelling in very bad condition (slum) 
* The cultural cognitive dissonance level is high for too long (cultural push).
* The price of the dwelling currently occupied exceeds the agent's income (in this case the agent is automatically put in "seek new place" mode)

## Land dynamics
The city is divided in 5 neighbourhoods (Central, NorthWest, NorthEast, SouthWest and SouthEast) of the same size (10x10), excluding the centre which is 4x4.

Every neighbourhood has an "**allure**", or reputation, based on the average cultural configuration of its inhabitants. This attribute is visible to perspective movers and tends to be "sticky", i.e. is updated seldom and not always reflects the actual composition of the neighbourhood. 

Dwellings' price and condition are initially set at a random value normalized in the 0-1 interval, with price being set at 0.25 above condition. Decay happens at every step by a fixed factor (currently 0.0016 per month, meaning that a property decays from 1 to 0 in 50 years) which is increased by 25% when the dwelling is empty. The price of the dwelling is adjusted every year and is decreased if the dwelling has been empty.

### Residential movement process
When an agent is set to relocate, or first enters the system, compares its culture string to the allure of each neighbourhood and finds the empty spots within the neighbourhood most similar to himself. Among the empty spots, the affordable ones are detected and among these, the agent moves to the one in the best condition and closest to the centre. Failing to find a suitable spot results in the agent trying in a different neighbourhood, then lowering its requirements and ultimately leaving the city.

# Results
## Effects of investment levels on house prices and distribution of agents

The model runs for 1200 ticks = 100 years.

For low levels of investment (**Kapital < 15** = ~3.4% of dwellings receiving investment each year) prices collapse in every neighbourhood and no clear differences in maintenance levels emerge: refurbished patches are scattered across the city. In this condition the population increases to its maximum and the income is average, since very low-priced housing is accessible to everybody.
**Version 0.2 Update** In the 0.2 version (with a threshold on investments being introduced, see above) after a while the city is no longer able to attract Kapital, because no patches present a sufficiently wide price-gap and all patches end up in the slum condition.

At **Kapital > 15** a pattern is visible: the centre of the city and the immediate surrounding area are constantly being maintained and achieving high prices, while the remaining neighbourhoods tend to very low prices and maintenance levels. Investments concentrate in the central area, where price gaps are systematically higher.

When Kapital reaches **K=25** (~6% of dwellings being refurbished each year) two or three entire neighbourhoods are able to attract all the investments. In this case the city tends to divide into two distinct areas, roughly of the same size: one with high price / high repair condition and one of slums.

Around this value the most interesting effects emerge. Gentrification can be spotted often, with neighbourhoods steadily increasing the mean income while the population decreases and increase abruptly, often in several waves, signalling that the poor go and the rich come. 

A **Kapital > 35** (refurbishing 8% per year) is able to trigger high prices/ high mainteniance in the whole city. The population is very low because only the richest immigrants can afford to enter the city. 
Interestingly, dissonance levels tend to be higher with higher investments. Even though there is no relation between income levels and culture, a high priced / highly selective city makes it difficult for agents to find compatible neighbours. Because the low population doesn't add enough diversity to the mix, a sort of "boring little village" effect or "boring white flight suburb" effect emerges.

## Cultural dynamics
Cultural uniformity is maximized in areas where prices have been stable for a long time at a high level. In these places a core of people can stay put, benefitting from the stable prices, and this allows for the allure value to reflect very accurately the actual composition of the neighbourhood. This situation self-selects the new entrants: wealthy people who can be choose the first-best neighbourhood and are already similar to the present residents.

Very little clustering happens in poor areas. This is clearly visible for values of K
20<K<30, where the city divides in two areas. The "slum" is a transition zone for poor immigrants, who quickly enter and leave.

# TODO

## Population growth
Agents reproduce around 27 years and die around 80. Reproduction is the replication of the cultural code of the parent with random mutation.

## State intervention
In a city where slums exist the state selects undeveloped, cheap properties (at least 4 neighbouring) and developes them setting the price at the level of the least wealthy agent. Longest term slum dwellers are then moved to the new property.

## Other ideas
* Look into cultural diversity and think of a clever way of linking income with culture
* Add a "fashion effect" towards certain cultural traits.
* Prices increase as a result of POPULARITY?
* Introduce population dynamics (growth, generations,..)
* Make the model more descriptive


# Changelog

## 0.4 - Census
### Census data sources
The population is now generated more realistically using census data regarding income, ethnicity and religion as follows:

* % Slums: % of dwellings with no central heating 2011 Census - LSOA2011
* % dwellings below average condition: Living environment deprivation index (only the dwelling-related bit) 2010 Census - LSOA2001
* Ethnicity: Black, White, Asian or 2011 Census - LSOA2011
* Religion: Christian, Muslim, Jewish, Other - 2011 Census - LSOA2011
* Income: “Model based” estimates 2007 - MSOA2001


We also use 2% as base yearly depreciation (doubled if empty for 6 months or more). 

Tried setting gaps according to local (moore) maximum or neighbourhood maximum. The latter case produces half of the city with completely unaffordable prices. Local maximum or neighbourhood average more realistic?


## 0.3.2
We now use WARDS.

## Version 0.3-GIS
### Manchester!
The model is now set in Manchester :-) House prices are actual, in absolute value £
Income is also set in real £££ and the initial distribution follows the actual distribution. (Median income £18000/year, Gini index 0.40).

### Monthly renovation and immigration
Renovation and immigration happen at every tick.

### Credit
The "Credit" variable is a multiplier

## Version 0.2-big
### City size
The city is 1692 patches and 12 neighbourhoods


### Strong neighbourhood preference
Choose the location with neighbourhood in 1st and 2nd best


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
NetLogo 5.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="15" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1440"/>
    <enumeratedValueSet variable="Kapital">
      <value value="0.015"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immigration-rate">
      <value value="0.015"/>
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kind">
      <value value="&quot;monocentric&quot;"/>
      <value value="&quot;policentric&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="area-gaps?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="areamax?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="write-csv?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="20" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1440"/>
    <enumeratedValueSet variable="Kapital">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profit-threshold">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immigration-rate">
      <value value="0.015"/>
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kind">
      <value value="&quot;monocentric&quot;"/>
      <value value="&quot;policentric&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="area-gaps?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="areamax?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="write-csv?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="30" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1440"/>
    <enumeratedValueSet variable="Kapital">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immigration-rate">
      <value value="0.015"/>
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Credit">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="write-csv?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kind">
      <value value="&quot;monocentric&quot;"/>
      <value value="&quot;policentric&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="area-gaps?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="areamax?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="essa2" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1400"/>
    <enumeratedValueSet variable="Kapital">
      <value value="0.02"/>
      <value value="0.04"/>
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="regenerate?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immigration-rate">
      <value value="0.007"/>
      <value value="0.012"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="essa1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1400"/>
    <enumeratedValueSet variable="Kapital">
      <value value="0.02"/>
      <value value="0.04"/>
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="regenerate?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immigration-rate">
      <value value="0.007"/>
      <value value="0.012"/>
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

# gentaxelling
An agent based model of urban dynamics based on the rent-gap theory

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

# Results [outdated]
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

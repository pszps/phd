dynamics = [
2600,1,0;
2600,1,0;
2600,1,0;
2600,1,0;
2600,1,0;
2600,1,0;
2600,1,0;
2600,1,0;
2600,1,0;
2600,1,0;
2600,1,0;
2600,1,0;
2600,1,0;
2600,1,0;
2600,1,0;
2597,4,0;
2596,5,0;
2596,5,0;
2594,7,0;
2590,10,1;
2589,9,3;
2585,13,3;
2580,18,3;
2574,24,3;
2569,27,5;
2557,38,6;
2546,45,10;
2537,49,15;
2521,63,17;
2511,69,21;
2502,73,26;
2491,77,33;
2481,81,39;
2467,90,44;
2442,107,52;
2415,129,57;
2394,146,61;
2354,177,70;
2318,202,81;
2260,251,90;
2213,277,111;
2161,309,131;
2105,348,148;
2012,419,170;
1945,460,196;
1870,507,224;
1787,557,257;
1688,620,293;
1616,645,340;
1509,709,383;
1422,757,422;
1333,790,478;
1246,827,528;
1152,877,572;
1071,889,641;
995,919,687;
936,929,736;
871,926,804;
795,945,861;
729,955,917;
678,941,982;
630,932,1039;
581,921,1099;
542,902,1157;
506,884,1211;
461,874,1266;
427,850,1324;
382,839,1380;
360,805,1436;
336,771,1494;
321,731,1549;
309,706,1586;
300,662,1639;
284,637,1680;
266,621,1714;
249,602,1750;
233,579,1789;
226,544,1831;
217,515,1869;
212,487,1902;
204,470,1927;
200,453,1948;
196,426,1979;
190,403,2008;
185,381,2035;
181,356,2064;
180,334,2087;
177,323,2101;
172,313,2116;
170,296,2135;
165,281,2155;
159,271,2171;
155,262,2184;
153,243,2205;
148,228,2225;
142,218,2241;
136,210,2255;
132,200,2269;
127,197,2277;
127,180,2294;
125,168,2308;
124,158,2319;
123,149,2329;
122,136,2343;
120,130,2351;
119,116,2366;
119,111,2371;
119,100,2382;
118,96,2387;
116,91,2394;
114,88,2399;
113,83,2405;
113,78,2410;
111,71,2419;
111,67,2423;
111,61,2429;
110,60,2431;
110,59,2432;
110,57,2434;
110,52,2439;
109,50,2442;
109,48,2444;
108,46,2447;
108,45,2448;
107,42,2452;
107,41,2453;
107,36,2458;
107,35,2459;
106,34,2461;
106,32,2463;
106,31,2464;
106,30,2465;
106,26,2469;
104,27,2470;
104,25,2472;
104,25,2472;
102,26,2473;
102,25,2474;
101,24,2476;
101,21,2479;
101,18,2482;
101,16,2484;
101,15,2485;
101,15,2485;
101,13,2487;
101,11,2489;
101,11,2489;
100,12,2489;
100,12,2489;
100,12,2489;
100,12,2489;
100,11,2490;
100,11,2490;
100,8,2493;
100,7,2494;
100,5,2496;
100,4,2497;
100,4,2497;
100,4,2497;
100,4,2497;
100,3,2498;
100,3,2498;
100,3,2498;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,2,2499;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,1,2500;
100,0,2501;
];
susceptible = dynamics (:, 1);
infected = dynamics (:, 2);
recovered = dynamics (:, 3);
totalPopulation = susceptible(1) + infected(1) + recovered(1);
susceptibleRatio = susceptible ./ totalPopulation;
infectedRatio = infected ./ totalPopulation;
recoveredRatio = recovered ./ totalPopulation;
steps = length (susceptible);
indices = 0 : steps - 1;
figure
plot (indices, susceptibleRatio.', 'color', 'blue', 'linewidth', 2);
hold on
plot (indices, infectedRatio.', 'color', 'red', 'linewidth', 2);
hold on
plot (indices, recoveredRatio.', 'color', 'green', 'linewidth', 2);
set(gca,'YTick',0:0.05:1.0);
xlabel ('Time');
ylabel ('Population Ratio');
legend('Susceptible','Infected', 'Recovered');
dynamics = [
990,10,0;
989,11,0;
988,12,0;
986,13,1;
985,13,2;
979,19,2;
973,24,3;
970,27,3;
962,33,5;
953,39,8;
944,42,14;
931,54,15;
923,60,17;
908,71,21;
892,81,27;
873,94,33;
849,108,43;
835,117,48;
806,139,55;
767,169,64;
728,193,79;
693,219,88;
660,235,105;
610,264,126;
572,282,146;
533,308,159;
508,317,175;
475,335,190;
448,337,215;
413,351,236;
385,365,250;
345,393,262;
323,384,293;
307,386,307;
277,390,333;
252,388,360;
230,387,383;
216,376,408;
202,363,435;
188,346,466;
178,329,493;
164,326,510;
153,317,530;
146,304,550;
138,297,565;
134,284,582;
125,271,604;
120,260,620;
112,252,636;
108,245,647;
103,238,659;
96,230,674;
86,233,681;
80,228,692;
73,223,704;
67,220,713;
66,216,718;
64,206,730;
61,194,745;
58,185,757;
57,169,774;
54,159,787;
50,154,796;
48,152,800;
47,147,806;
45,140,815;
44,135,821;
42,131,827;
42,124,834;
40,117,843;
40,113,847;
39,106,855;
38,102,860;
38,96,866;
37,93,870;
35,88,877;
35,80,885;
34,76,890;
34,72,894;
34,68,898;
34,64,902;
33,60,907;
33,57,910;
32,54,914;
31,50,919;
31,45,924;
31,43,926;
31,41,928;
31,35,934;
31,31,938;
31,28,941;
31,26,943;
30,26,944;
30,26,944;
29,26,945;
29,24,947;
29,21,950;
29,21,950;
29,20,951;
29,18,953;
28,19,953;
28,19,953;
28,18,954;
28,16,956;
28,14,958;
28,14,958;
28,12,960;
27,13,960;
27,11,962;
27,10,963;
27,10,963;
27,9,964;
27,9,964;
27,9,964;
27,9,964;
27,9,964;
27,8,965;
27,7,966;
27,5,968;
27,4,969;
27,4,969;
27,4,969;
27,3,970;
27,2,971;
27,2,971;
27,2,971;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
27,1,972;
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
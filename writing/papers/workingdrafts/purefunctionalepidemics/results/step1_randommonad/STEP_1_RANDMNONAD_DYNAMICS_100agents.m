dynamics = [
99.0,1.0,0.0;
99.0,1.0,0.0;
98.0,2.0,0.0;
97.0,3.0,0.0;
96.0,3.0,1.0;
95.0,4.0,1.0;
95.0,3.0,2.0;
93.0,5.0,2.0;
93.0,4.0,3.0;
93.0,4.0,3.0;
91.0,6.0,3.0;
90.0,7.0,3.0;
86.0,9.0,5.0;
85.0,10.0,5.0;
79.0,16.0,5.0;
76.0,19.0,5.0;
71.0,22.0,7.0;
67.0,26.0,7.0;
60.0,32.0,8.0;
57.0,30.0,13.0;
53.0,31.0,16.0;
51.0,32.0,17.0;
48.0,35.0,17.0;
45.0,38.0,17.0;
39.0,43.0,18.0;
36.0,44.0,20.0;
34.0,44.0,22.0;
31.0,42.0,27.0;
29.0,43.0,28.0;
27.0,42.0,31.0;
26.0,41.0,33.0;
26.0,35.0,39.0;
26.0,31.0,43.0;
25.0,29.0,46.0;
25.0,27.0,48.0;
24.0,26.0,50.0;
22.0,25.0,53.0;
20.0,27.0,53.0;
20.0,25.0,55.0;
19.0,26.0,55.0;
17.0,24.0,59.0;
15.0,25.0,60.0;
13.0,24.0,63.0;
13.0,24.0,63.0;
10.0,26.0,64.0;
10.0,24.0,66.0;
10.0,22.0,68.0;
9.0,19.0,72.0;
9.0,16.0,75.0;
9.0,15.0,76.0;
9.0,14.0,77.0;
9.0,14.0,77.0;
8.0,14.0,78.0;
6.0,16.0,78.0;
6.0,16.0,78.0;
6.0,15.0,79.0;
6.0,14.0,80.0;
6.0,12.0,82.0;
6.0,11.0,83.0;
6.0,11.0,83.0;
6.0,11.0,83.0;
6.0,10.0,84.0;
6.0,8.0,86.0;
6.0,8.0,86.0;
6.0,8.0,86.0;
6.0,7.0,87.0;
5.0,7.0,88.0;
5.0,7.0,88.0;
4.0,7.0,89.0;
4.0,7.0,89.0;
4.0,6.0,90.0;
4.0,5.0,91.0;
4.0,5.0,91.0;
4.0,4.0,92.0;
4.0,4.0,92.0;
4.0,3.0,93.0;
4.0,3.0,93.0;
4.0,3.0,93.0;
3.0,4.0,93.0;
3.0,3.0,94.0;
3.0,3.0,94.0;
3.0,3.0,94.0;
3.0,2.0,95.0;
3.0,1.0,96.0;
3.0,1.0,96.0;
3.0,1.0,96.0;
3.0,1.0,96.0;
3.0,1.0,96.0;
3.0,1.0,96.0;
3.0,1.0,96.0;
3.0,1.0,96.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
3.0,0.0,97.0;
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

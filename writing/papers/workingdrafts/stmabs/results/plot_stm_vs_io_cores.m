stm = [53.182, 27.817, 21.776, 20.201];
io = [60.564, 42.779, 38.614, 41.914];
cores = [1, 2, 3, 4];

figure;
plot (cores, stm, "linewidth", 2, "color", [0, 0.7, 0]);
hold on;
plot (cores, io, "linewidth", 2, "color", [0.7, 0, 0]);

legend ("STM", "IO");
xlabel ("Cores");
ylabel ("Average Time sec.");

title ("Performance STM vs IO on 51x51 Grid with varying Cores");
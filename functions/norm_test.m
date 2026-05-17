function h = norm_test(data)
    mu = mean(data);
    sigma = std(data);
    [h, p] = kstest((data - mu) / sigma);
end
function seq = primeSequence(n,type)
% Return the first N primes of the given sequence type. Four sequence types
% supported: Eisenstein, Balanced, Isolated and Gaussian.
    arguments(Input)
        n double    % Length of the generated sequence
        type string % Name of the sequence to generate
    end
    arguments(Output)
        seq double  % Generated sequence of prime numbers
    end

    seq = feval(type,n);

end

function seq = eisenstein(n)
% All the primes that are congruent to 2 (mod 3)
    seq = zeros(1,n);
    N = 1;
    p = 2;
    while N <= n
        if isprime(p) && mod(p,3) == 2
            seq(N) = p;
            N = N + 1;
        end
        p = p + 1;
    end
end

function seq = balanced(n)
% Equal sized prime gaps to either side. Equal to sum of nearest primes
% before and after.
    seq = zeros(1,n);
    N = 1;
    p = 0;
    while N <= n
        p = p + 1;
        while isprime(p) == false
            p = p + 1;
        end
        
        next = p + 1;
        while isprime(next) == false
            next = next + 1;
        end

        previous = p - 1;
        while previous > 0 && isprime(previous) == false
            previous = previous - 1;
        end

        if p == (previous + next) / 2
            seq(N) = p;
            N = N + 1;
        end
    end
end

function seq = isolated(n)
% Neither p-2 nor p+2 is prime
    seq = zeros(1,n);
    N = 1;
    p = 0;
    while N <= n
        p = p + 1;
        while isprime(p) == false
            p = p + 1;
        end
        if isprime(p-2) == false && isprime(p+2) == false
            seq(N) = p;
            N = N + 1;
        end
    end
end

function seq = gaussian(n)
% Primes of the form 4n-3
    seq = zeros(1,n);
    N = 1;
    m = 0;
    while N <= n
        p = 1;
        while isprime(p) == false
            p = (4 * m) + 3;
            m = m + 1;
        end
        seq(N) = p;
        N = N + 1;
    end
end

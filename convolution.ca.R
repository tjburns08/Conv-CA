# Date: December 1, 2017
# Procedure: Convolution for cellular automata
# Purpose: to produce a CA solution to conways game of life

###################### SETUP ###################### 
library(sp)
library(reshape)
library(ggplot2)
library(animation)
library(spatialfil)
library(tidyverse)

###################### DESCRPTION ######################

# Solves Conway's Game of Life and other 2D CA by performing convolution
# of a bitwise matrix

# Convolution creates a "number of neighbors" matrix, which is iterated over
# According to the CA rules (which revolve around the number of neighbors)

# This allows not only a simple implementation of CA, but the ability to 
# create new CA not only from changing rules, but changing the kernel


###################### FUNCTIONS ######################

# This function comes from the following:
# http://johnramey.net/blog/2011/06/05/conways-game-of-life-in-r-with-ggplot2-and-animation/
grid_to_ggplot <- function(grid) {
    # Permutes the matrix so that melt labels this correctly.
    grid <- grid[seq.int(nrow(grid), 1), ]
    grid <- melt(grid)
    grid$value <- factor(ifelse(grid$value, "Alive", "Dead"))
    p <- ggplot(grid, aes(x=X1, y=X2, z = value, color = value))
    p <- p + geom_tile(aes(fill = value))
    p  + scale_fill_manual(values = c("Dead" = "white", "Alive" = "black"))
}

# Start with a simple bitwise matrix
# Generates random matrix of 0 and 1s
# Args:
#   side: the length of one side
#   prob: vector of two numbers indicating the probability of respective 0 and 1
# Returns: 
#   result: the matrix of 0 and 1 of length "side" and respective probability of "prob"
generate.space <- function(side, prob) {
    result <- matrix(sample(c(0, 1), side^2, replace = TRUE, prob = prob), nrow = side)
    return(result)
}

# Convolution based nn summer
# Generates a kernel to be used across the "space" matrix
# Args:
#   side: the length of the side of the kernel
# Returns:
#   result: a matrix of only 0. 
generate.kernel <- function(side) {
    result <- matrix(rep(0, side^2), nrow = side)
    return(result)
}

# Makes the nn matrix given space and a kernel matrix
# Args:
#   space: the matrix representing the space of the CA
#   kernel: the matrix representing the kernel to be iterated across space
# Returns: 
#   result: the nn matrix generated by the kernal iterating across space
convolution <- function(space, kernel) {
    
    tmp <- space
    # Make sure the kernel stays within bounds of the matrix 
    # Note tha this only really works for an odd numbered matrix
    if(nrow(kernel) %% 2 == 0) {
        stop("Please choose a kernel with an odd number of sides")
    }
    
    # Find the dimensions for the for loop
    start <- nrow(kernel) %/% 2 + 1
    end <- nrow(space) - start
    to.edge <- start - 1
    
    # The loop
    for(i in start:end) {
        for(j in start:end) {
            piece <- space[(j - to.edge):(j + to.edge), (i - to.edge):(i + to.edge)]
            tmp[j, i] <- sum(piece * kernel)
        }
    }
    
    return(tmp)
}

# Implements Conway's game of life rules on a nn matrix
# Args: 
#   m: the original matrix
#   tmp: the nn matrix from the convolution step
# Returns: 
#   m: the next iteration of the original matrix m
gol.rules <- function(m, tmp) {
    m <- ifelse(tmp < 2 & m == 1, 0, m)
    m <- ifelse(tmp > 3 & m == 1, 0, m)
    m <- ifelse((tmp == 2 | tmp == 3) & m == 1, 1, m)
    m <- ifelse(tmp == 3 & m == 0, 1, m)
    return(m)
}

# Generalized version of GOL rules for larger kernels
# Args:
#   m: orignal space matrix
#   tmp: nn matrix of conv step
#   kernel: the kernel being used
# Returns: 
#   m: the next iteration of the original matrix m
general.gol.rules <- function(m, tmp, kernel) {
    s <- nrow(kernel)^2 - 1
    m <- ifelse(tmp < s/4 & m == 1, 0, m)
    m <- ifelse(tmp > 3*s/8 & m == 1, 0, m) # here is where it differs
    m <- ifelse((tmp >= s/4 & tmp <= 3*s/8) & m == 1, 1, m)
    m <- ifelse(tmp == 3*s/8 & m == 0, 1, m)
}


# Runs single iteration of CA
# Args:
#   space: the matrix representing the CA space
#   kernel: the kernel for convolution of space
#   vis: boolean indicating whether this should be graphed
# Returns: 
#   the space matrix after one iteration. Also plots it as needed
gol.iter <- function(space, kernel, vis, general = FALSE) {
    tmp <- convolution(space, kernel)
    if(general == TRUE) {
        space <- general.gol.rules(space, tmp, kernel)
    } else {
        space <- gol.rules(space, tmp)
    }

    return(space)
}

# Produces a ring of a specific number on the outsize of a matrix of zeros
# Args:
#   m: matrix of zeros
#   number: the number you would like to have on the outside of the matrix
ring.outside <- function(m, number) {
    for(i in 1:nrow(m)) {
        for(j in 1:nrow(m)) {
            if(i == 1 | j == 1 | i == nrow(m) | j == nrow(m)) {
                m[i, j] <- number
            } 
        }
    }
    return(m)
}


# Produces a randomized kernel based on numbers of interest and probabilities
# of said numbers
# Args
#   m: matrix of zeros
#   numbers: set of numbers to be included in kernel
#   probs: probabilities for each respective number to appear
# Returns:
#   matrix conforming to the specified numbers and probabilities
randomize.kernel <- function(m, numbers, probs) {
    for(i in 1:nrow(m)) {
        for(j in 1:nrow(m)) {
            m[i, j] <- sample(numbers, 1, replace = FALSE, prob = probs)
        }
    }
    return(m)
}

# Generates a shuffled kernel with an exact number of sides and number of ones
# Args:
#   side: length/width of matrix
#   num.ones: the number of 1's to be put in the matrix (the rest is zero)
# Returns: 
#   result: the shuffled kernel with the exact number of ones
generate.shuffled.kernel <- function(side, num.ones) {
    content <- c(rep(1, num.ones), rep(0, side^2 - num.ones))
    content <- sample(content, size = length(content), FALSE)
    result <- matrix(content, nrow = side)
    return(result)
}

###################### GOL RULES AND PRE DETERMINED KERNEL #####################

# Intresting kernels:
gol <- matrix(c(1, 1, 1, 1, 0, 1, 1, 1, 1), nrow = 3) # Game of life
gol.self.centered <- matrix(c(1, 1, 1, 1, 1, 1, 1, 1, 1), nrow = 3) # Game of life including itself
jellyfish <- matrix(c(1, 2, 1, 1, 0, 1, 1, 1, 1), nrow = 3) # Literally
stack <- matrix(c(1, 2, 1, 1, 0, 1, 1, 2, 1), nrow = 3)
bacteria <- matrix(c(1, 2, 1, 2, 0, 1, 1, 2, 1), nrow = 3)
exp.block <- matrix(c(1, 2, 1, 2, 0, 2, 1, 2, 1), nrow = 3)
q.mark <- matrix(c(2, 1, 1, 1, 0, 1, 1, 1, 1), nrow = 3)
osc.colon <- matrix(c(2, 1, 1, 1, 0, 1, 1, 1, 2), nrow = 3) 
osc <- matrix(c(0, 2, 1, 1, 0, 1, 1, 2, 0), nrow = 3) # Interesting oscillators
osc.2 <- matrix(c(2, 0, 1, 1, 0, 1, 1, 0, 2), nrow = 3) # Interesting oscillators
gol.larger <- matrix(c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1), nrow = 5)


# Quantum (use with general = FALSE)
# Note that this might need better rules to be fully utilized
spooky.action <- generate.kernel(5) %>% ring.outside(., 1)


# Produce plots using pre-defined kernels (above) and game of life rules
ntimes <- 100 # Number of iterations
space <- generate.space(side = 100, prob = c(0.5, 0.5)) # Starting bitwise matrix
kernel <- gol # choose the kernel from below. Gol = game of life
# Produces the list of plots
ca.plot.list <- lapply(1:ntimes, function(i) {
    space <<- gol.iter(space = space, kernel = kernel, vis = FALSE, general = TRUE) 
    p <- grid_to_ggplot(space)
    return(p)
}) 

# You can animate it here by producing the plots and flipping through them
# Notice I set them to be backwards, so the first one is at the top of the stack
# in Rstudio. 
# So print this and wait for it all to be done. Don't look at the screen because
# The flashing is hard on the eyes.

# If you're using Rstudio, don't delete plots while this is still running
# This will cause Rstudio to crash. Stop the program first using the little
# Stop sign. 
lapply(length(ca.plot.list):(ntimes - 100), function(i) {
    print(ca.plot.list[[i]])
    Sys.sleep(0.1) # Becuase it otherwise acts funny
})

###################### GOL RULES AND RANDOM KERNEL ######################

# Brute force geenration of random kernels with GOL rules, to find interesting
# rules. Note that most of the kernels will be assymetrical in this iteration
# Leaving to interesting shifting to occur. 

# Space
space <- generate.space(side = 100, prob = c(0.9, 0.1))
kernel <- generate.shuffled.kernel(side = 5, num.ones = 6)

sapply(ca.list, sum)
age.of.universe <- 100

# Each element of the list will be a new kernel applied to a bitwise matrix
ca.battery <- lapply(1:age.of.universe, function(i) {
    print(i)
    space <- generate.space(side = 100, prob = c(0.5, 0.5))
    kernel <- generate.exact.kernel(side = 5, num.ones = 6)
    ntimes <- 1000
    # Sum up the number of populated squares
    ca.list <- lapply(1:ntimes, function(i) {
        space <<- gol.iter(space = space, kernel = kernel, vis = FALSE) 
        return(space)
    }) 
    
    result <- sapply(ca.list, sum)
    return(list(space = space, kernel = kernel, sum.vector = result))
})


# This computes the total number of cells for each list at the end of the run
# which allows one to determine if it "explodes" is driven to zero, or 
# stays in the middle (as GOL would)
ca.summary <- sapply(ca.battery, function(i) {
    sum.vector <- i$sum.vector
    return(sum.vector[length(sum.vector)])
})

# This shows what CA had final numbers of between x and y "on" in order
# to find CA that don't explode or drive to zero
smallest <- 300
largest <- 1000
of.interest <- which(ca.summary > smallest & ca.summary < largest)







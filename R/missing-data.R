#########################################
## Dealing with Missing Data in SparkR ##
#########################################

## Sarah Armstrong, Urban Institute  
## July 6, 2016  
## Last Updated: August 17, 2016


## Objective: In this tutorial, we discuss general strategies for dealing with missing data in the SparkR environment. While we do not consider conceptually how and why we might impute missing values in a dataset, we do discuss logistically how we could drop rows with missing data and impute missing data with replacement values. We specifically consider the following during this tutorial:
  
## * Specify null values when loading data in as a DF
## * Conditional expressions on empty DF entries
##     + Null and NaN indicator operations
##     + Conditioning on empty string entries
##     + Distribution of missing data across grouped data
## * Drop rows with missing data
##     + Null value entries
##     + Empty string entries
## * Fill missing data entries
##     + Null value entries
##     + Empty string entries

## SparkR/R Operations Discussed: `read.df` (`nullValue = "<string>"`), `printSchema`, `nrow`, `isNull`, `isNotNull`, `isNaN`, `count`, `where`, `agg`, `groupBy`, `n`, `collect`, `dropna`, `na.omit`, `list`, `fillna`


## Initiate SparkR session:

if (nchar(Sys.getenv("SPARK_HOME")) < 1) {
  Sys.setenv(SPARK_HOME = "/home/spark")
}
library(SparkR, lib.loc = c(file.path(Sys.getenv("SPARK_HOME"), "R", "lib")))
sparkR.session()

##############################################################################
## (1) Specify null values when loading data in as a SparkR DataFrame (DF): ##
##############################################################################
  
## Throughout this tutorial, we will use the loan performance example dataset that we exported at the conclusion of the [SparkR Basics I](https://github.com/UrbanInstitute/sparkr-tutorials/blob/master/sparkr-basics-1.md) tutorial. Note that we now include the `na.strings` option in the `read.df` transformation below. By setting `na.strings` equal to an empty string in `read.df`, we direct SparkR to interpret empty entries in the dataset as being equal to nulls in `df`. Therefore, any DF entries matching this string (here, set to equal an empty entry) will be set equal to a null value in `df`.

df <- read.df("s3://sparkr-tutorials/hfpc_ex", header = "false", inferSchema = "true", na.strings = "")
cache(df)

## We can replace this empty string with any string that we know indicates a null entry in the dataset, i.e. with `na.strings="<string>"`. Note that SparkR only reads empty entries as null values in numerical and integer datatype (dtype) DF columns, meaning that empty entries in DF columns of string dtype will simply equal an empty string. We consider how to work with this type of observation throughout this tutorial alongside our treatment of null values.

## With `printSchema`, we can see the dtype of each column in `df` and, noting which columns are of a numerical and integer dtypes and which are string, use this to determine how we should examine missing data in each column of `df`. We also count the number of rows in `df` so that we can compare this value to row counts that we compute throughout this tutorial:
  
printSchema(df)
(n <- nrow(df))

######################################################
## (2) Conditional expressions on empty DF entries: ##
######################################################
  
#############################################
## (2i) Null and NaN indicator operations: ##
#############################################
  
## We saw in the subsetting tutorial how to subset a DF by some conditional statement. We can extend this reasoning in order to identify missing data in a DF and to explore the distribution of missing data within a DF. SparkR operations indicating null and NaN entries in a DF are `isNull`, `isNaN` and `isNotNull`, and these can be used in conditional statements to locate or to remove DF rows with null and NaN entries.

## Below, we count the number of missing entries in `"loan_age"` and in `"mths_remng"`, which are both of integer dtype. We can see below that there are no missing or NaN entries in `"loan_age"`. Note that the `isNull` and `isNaN` count results differ for `"mths_remng"` - while there are missing values in `"mths_remng"`, there are no NaN entries (entires that are "not a number").

df_laNull <- where(df, isNull(df$loan_age))
count(df_laNull)
df_laNaN <- where(df, isNaN(df$loan_age))
count(df_laNaN)

df_mrNull <- where(df, isNull(df$mths_remng))
count(df_mrNull)
df_mrNaN <- where(df, isNaN(df$mths_remng))
count(df_mrNaN)

#################################
## (2ii) Empty string entries: ##
#################################

## If we want to count the number of rows with missing entries for `"servicer_name"` (string dtype) we can simply use the equality logical condition (==) to direct SparkR to `count` the number of rows `where` the entries in the `"servicer_name"` column are equal to an empty string:
  
df_snEmpty <- where(df, df$servicer_name == "")
count(df_snEmpty)

##############################################################
## (2iii) Distribution of missing data across grouped data: ##
##############################################################

## We can also condition on missing data when aggregating over grouped data in order to see how missing data is distributed over a categorical variable within our data. In order to view the distribution of `"mths_remng"` observations with null values over distinct entries of `"servicer_name"`, we (1) group the entries of the DF `df_mrNull` that we created in the preceding example over `"servicer_name"` entries, (2) create the DF `mrNull_by_sn` which consists of the number of observations in `df_mrNull` by `"servicer_name"` entries and (3) collect `mrNull_by_sn` into a nicely formatted table as a local data.frame:
  
gb_sn_mrNull <- groupBy(df_mrNull, df_mrNull$servicer_name)
mrNull_by_sn <- agg(gb_sn_mrNull, Nulls = n(df_mrNull$servicer_name))

mrNull_by_sn.dat <- collect(mrNull_by_sn)
mrNull_by_sn.dat
# Alternatively, we could have evaluated showDF(mrNull_by_sn) to print DF

## Note that the resulting data.frame lists only nine (9) distinct string values for `"servicer_name"`. So, any row in `df` with a null entry for `"mths_remng"` has one of these strings as its corresponding `"servicer_name"` value. We could similarly examine the distribution of missing entries for some string dtype column across grouped data by first filtering a DF on the condition that the string column is equal to an empty string, rather than filtering with a null indicator operation (e.g. `isNull`), then performing the `groupBy` operation.

######################################
## (3) Drop rows with missing data: ##
######################################

##############################
## (3i) Null value entries: ##
##############################
  
## The SparkR operation `dropna` (or its alias `na.omit`) creates a new DF that omits rows with null value entries. We can configure `dropna` in a number of ways, including whether we want to omit rows with nulls in a specified list of DF columns or across all columns within a DF.

## If we want to drop rows with nulls for a list of columns in `df`, we can define a list of column names and then include this in `dropna` or we could embed this list directly in the operation. Below, we explicitly define a list of column names on which we condition `dropna`:
  
mrlist <- list("mths_remng", "aj_mths_remng")
df_mrNoNulls <- dropna(df, cols = mrlist)
nrow(df_mrNoNulls)

## Alternatively, we could `filter` the DF using the `isNotNull` condition as follows:
  
df_mrNoNulls_ <- filter(df, isNotNull(df$mths_remng) & isNotNull(df$aj_mths_remng))
nrow(df_mrNoNulls_)

## If we want to consider all columns in a DF when omitting rows with null values, we can use either the `how` or `minNonNulls` paramters of `dropna`.

## The parameter `how` allows us to decide whether we want to drop a row if it contains `"any"` nulls or if we want to drop a row only if `"all"` of its entries are nulls. We can see below that there are no rows in `df` in which all of its values are null, but only a small percentage of the rows in `df` have no null value entries:
  
df_all <- dropna(df, how = "all")
nrow(df_all)    # Equal in value to n

df_any <- dropna(df, how = "any")
(n_any <- nrow(df_any))
(n_any/n)*100

## We can set a minimum number of non-null entries required for a row to remain in the DF by specifying a `minNonNulls` value. If included in `dropna`, this specification directs SparkR to drop rows that have less than `minNonNulls = <value>` non-null entries. Note that including `minNonNulls` overwrites the `how` specification. Below, we omit rows with that have less than 5 and 12 entries that are _not_ nulls. Note that there are no rows in `df` that have less than 5 non-null entries, and there are only approximately 8,000 rows with less than 12 non-null entries.

df_5 <- dropna(df, minNonNulls = 5)
nrow(df_5)    # Equal in value to n

df_12 <- dropna(df, minNonNulls = 12)
(n_12 <- nrow(df_12))
n - n_12

#################################
## (3ii) Empty string entries: ##
#################################

## If we want to create a new DF that does not include any row with missing entries for a column of string dtype, we could also use `filter` to accomplish this. In order to remove observations with a missing `"servicer_name"` value, we simply filter `df` on the condition that `"servicer_name"` does not equal an empty string entry:
  
df_snNoEmpty <- filter(df, df$servicer_name != "")
nrow(df_snNoEmpty)

####################################
## (4) Fill missing data entries: ##
####################################
  
##############################
## (4i) Null value entries: ##
##############################
  
## The `fillna` operation allows us to replace null entries with some specified value. In order to replace null entries in every numerical and integer column in `df` with a value, we simply evaluate the expression `fillna(df, <value>)`. We replace every null entry in `df` with the value 12345 below:

str(df)

df_ <- fillna(df, value = 12345)
str(df_)
rm(df_)

## If we want to replace null values within a list of DF columns, we can specify a column list just as we did in `dropna`. Here, we replace the null values in only `"act_endg_upb"` with 12345:
  
str(df)

df_ <- fillna(df, list("act_endg_upb" = 12345))
str(df_)
rm(df_)

#################################
## (4ii) Empty string entries: ##
#################################

## Finally, we can replace the empty entries in string dtype columns with the `ifelse` operation, which follows the syntax `ifelse(<test>, <if true>, <if false>)`. Here, we replace the empty entries in `"servicer_name"` with the string `"Unknown"`:
  
str(df)
df$servicer_name <- ifelse(df$servicer_name == "", "Unknown", df$servicer_name)
str(df)
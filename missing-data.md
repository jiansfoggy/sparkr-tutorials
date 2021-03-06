# Dealing with Missing Data in SparkR
Sarah Armstrong, Urban Institute  
July 8, 2016  
  


**Last Updated**: August 17, 2016


**Objective**: In this tutorial, we discuss general strategies for dealing with missing data in the SparkR environment. While we do not consider conceptually how and why we might impute missing values in a dataset, we do discuss logistically how we could drop rows with missing data and impute missing data with replacement values. We specifically consider the following during this tutorial:
  
* Specify null values when loading data in as a DF
* Conditional expressions on empty DF entries
    + Null and NaN indicator operations
    + Conditioning on empty string entries
    + Distribution of missing data across grouped data
* Drop rows with missing data
    + Null value entries
    + Empty string entries
* Fill missing data entries
    + Null value entries
    + Empty string entries

**SparkR/R Operations Discussed**: `read.df` (`nullValue = "<string>"`), `printSchema`, `nrow`, `isNull`, `isNotNull`, `isNaN`, `count`, `where`, `agg`, `groupBy`, `n`, `collect`, `dropna`, `na.omit`, `list`, `fillna`

***

:heavy_exclamation_mark: **Warning**: Before beginning this tutorial, please visit the SparkR Tutorials README file (found [here](https://github.com/UrbanInstitute/sparkr-tutorials/blob/master/README.md)) in order to load the SparkR library and subsequently initiate a SparkR session.



The following error indicates that you have not initiated a SparkR session:


```r
Error in getSparkSession() : SparkSession not initialized
```

If you receive this message, return to the SparkR tutorials [README](https://github.com/UrbanInstitute/sparkr-tutorials/blob/master/README.md) for guidance.

***
  
### Specify null values when loading data in as a SparkR DataFrame (DF)
  
Throughout this tutorial, we will use the loan performance example dataset that we exported at the conclusion of the [SparkR Basics I](https://github.com/UrbanInstitute/sparkr-tutorials/blob/master/sparkr-basics-1.md) tutorial. Note that we now include the `na.strings` option in the `read.df` transformation below. By setting `na.strings` equal to an empty string in `read.df`, we direct SparkR to interpret empty entries in the dataset as being equal to nulls in `df`. Therefore, any DF entries matching this string (here, set to equal an empty entry) will be set equal to a null value in `df`.


```r
df <- read.df("s3://sparkr-tutorials/hfpc_ex", header = "false", inferSchema = "true", na.strings = "")
cache(df)
```

We can replace this empty string with any string that we know indicates a null entry in the dataset, i.e. with `na.strings="<string>"`. Note that SparkR only reads empty entries as null values in numerical and integer datatype (dtype) DF columns, meaning that empty entries in DF columns of string dtype will simply equal an empty string. We consider how to work with this type of observation throughout this tutorial alongside our treatment of null values.


With `printSchema`, we can see the dtype of each column in `df` and, noting which columns are of a numerical and integer dtypes and which are string, use this to determine how we should examine missing data in each column of `df`. We also count the number of rows in `df` so that we can compare this value to row counts that we compute throughout this tutorial:
  

```r
printSchema(df)
## root
##  |-- loan_id: long (nullable = true)
##  |-- period: string (nullable = true)
##  |-- servicer_name: string (nullable = true)
##  |-- new_int_rt: double (nullable = true)
##  |-- act_endg_upb: double (nullable = true)
##  |-- loan_age: integer (nullable = true)
##  |-- mths_remng: integer (nullable = true)
##  |-- aj_mths_remng: integer (nullable = true)
##  |-- dt_matr: string (nullable = true)
##  |-- cd_msa: integer (nullable = true)
##  |-- delq_sts: string (nullable = true)
##  |-- flag_mod: string (nullable = true)
##  |-- cd_zero_bal: integer (nullable = true)
##  |-- dt_zero_bal: string (nullable = true)
(n <- nrow(df))
## [1] 13216516
```

_Note_: documentation for the quarterly loan performance data can be found at http://www.fanniemae.com/portal/funding-the-market/data/loan-performance-data.html.

***
  
  
### Conditional expressions on empty DF entries
  
  
#### Null and NaN indicator operations
  
We saw in the subsetting tutorial how to subset a DF by some conditional statement. We can extend this reasoning in order to identify missing data in a DF and to explore the distribution of missing data within a DF. SparkR operations indicating null and NaN entries in a DF are `isNull`, `isNaN` and `isNotNull`, and these can be used in conditional statements to locate or to remove DF rows with null and NaN entries.


Below, we count the number of missing entries in `"loan_age"` and in `"mths_remng"`, which are both of integer dtype. We can see below that there are no missing or NaN entries in `"loan_age"`. Note that the `isNull` and `isNaN` count results differ for `"mths_remng"` - while there are missing values in `"mths_remng"`, there are no NaN entries (entires that are "not a number").


```r
df_laNull <- where(df, isNull(df$loan_age))
count(df_laNull)
## [1] 0
df_laNaN <- where(df, isNaN(df$loan_age))
count(df_laNaN)
## [1] 0

df_mrNull <- where(df, isNull(df$mths_remng))
count(df_mrNull)
## [1] 8314
df_mrNaN <- where(df, isNaN(df$mths_remng))
count(df_mrNaN)
## [1] 0
```


#### Empty string entries

If we want to count the number of rows with missing entries for `"servicer_name"` (string dtype) we can simply use the equality logical condition (==) to direct SparkR to `count` the number of rows `where` the entries in the `"servicer_name"` column are equal to an empty string:
  

```r
df_snEmpty <- where(df, df$servicer_name == "")
count(df_snEmpty)
## [1] 12923942
```


#### Distribution of missing data across grouped data

We can also condition on missing data when aggregating over grouped data in order to see how missing data is distributed over a categorical variable within our data. In order to view the distribution of `"mths_remng"` observations with null values over distinct entries of `"servicer_name"`, we (1) group the entries of the DF `df_mrNull` that we created in the preceding example over `"servicer_name"` entries, (2) create the DF `mrNull_by_sn` which consists of the number of observations in `df_mrNull` by `"servicer_name"` entries and (3) collect `mrNull_by_sn` into a nicely formatted table as a local data.frame:
  

```r
gb_sn_mrNull <- groupBy(df_mrNull, df_mrNull$servicer_name)
mrNull_by_sn <- agg(gb_sn_mrNull, Nulls = n(df_mrNull$servicer_name))

mrNull_by_sn.dat <- collect(mrNull_by_sn)
mrNull_by_sn.dat
##                             servicer_name Nulls
## 1                NATIONSTAR MORTGAGE, LLC     1
## 2                  WELLS FARGO BANK, N.A.    16
## 3 FANNIE MAE/SETERUS, INC. AS SUBSERVICER     4
## 4                    DITECH FINANCIAL LLC     2
## 5                                   OTHER    16
## 6                      CITIMORTGAGE, INC.     4
## 7                          PNC BANK, N.A.     2
## 8                                          8264
## 9               GREEN TREE SERVICING, LLC     5
# Alternatively, we could have evaluated showDF(mrNull_by_sn) to print DF
```

Note that the resulting data.frame lists only nine (9) distinct string values for `"servicer_name"`. So, any row in `df` with a null entry for `"mths_remng"` has one of these strings as its corresponding `"servicer_name"` value. We could similarly examine the distribution of missing entries for some string dtype column across grouped data by first filtering a DF on the condition that the string column is equal to an empty string, rather than filtering with a null indicator operation (e.g. `isNull`), then performing the `groupBy` operation.

***
  
  
### Drop rows with missing data
  
  
#### Null value entries
  
The SparkR operation `dropna` (or its alias `na.omit`) creates a new DF that omits rows with null value entries. We can configure `dropna` in a number of ways, including whether we want to omit rows with nulls in a specified list of DF columns or across all columns within a DF.


If we want to drop rows with nulls for a list of columns in `df`, we can define a list of column names and then include this in `dropna` or we could embed this list directly in the operation. Below, we explicitly define a list of column names on which we condition `dropna`:
  

```r
mrlist <- list("mths_remng", "aj_mths_remng")
df_mrNoNulls <- dropna(df, cols = mrlist)
nrow(df_mrNoNulls)
## [1] 13080394
```

Alternatively, we could `filter` the DF using the `isNotNull` condition as follows:
  

```r
df_mrNoNulls_ <- filter(df, isNotNull(df$mths_remng) & isNotNull(df$aj_mths_remng))
nrow(df_mrNoNulls_)
## [1] 13080394
```

If we want to consider all columns in a DF when omitting rows with null values, we can use either the `how` or `minNonNulls` paramters of `dropna`.


The parameter `how` allows us to decide whether we want to drop a row if it contains `"any"` nulls or if we want to drop a row only if `"all"` of its entries are nulls. We can see below that there are no rows in `df` in which all of its values are null, but only a small percentage of the rows in `df` have no null value entries:
  

```r
df_all <- dropna(df, how = "all")
nrow(df_all)    # Equal in value to n
## [1] 13216516

df_any <- dropna(df, how = "any")
(n_any <- nrow(df_any))
## [1] 419277
(n_any/n)*100
## [1] 3.172372
```

We can set a minimum number of non-null entries required for a row to remain in the DF by specifying a `minNonNulls` value. If included in `dropna`, this specification directs SparkR to drop rows that have less than `minNonNulls = <value>` non-null entries. Note that including `minNonNulls` overwrites the `how` specification. Below, we omit rows with that have less than 5 and 12 entries that are _not_ nulls. Note that there are no rows in `df` that have less than 5 non-null entries, and there are only approximately 8,000 rows with less than 12 non-null entries.


```r
df_5 <- dropna(df, minNonNulls = 5)
nrow(df_5)    # Equal in value to n
## [1] 13216516

df_12 <- dropna(df, minNonNulls = 12)
(n_12 <- nrow(df_12))
## [1] 13208298
n - n_12
## [1] 8218
```


#### Empty string entries

If we want to create a new DF that does not include any row with missing entries for a column of string dtype, we could also use `filter` to accomplish this. In order to remove observations with a missing `"servicer_name"` value, we simply filter `df` on the condition that `"servicer_name"` does not equal an empty string entry:
  

```r
df_snNoEmpty <- filter(df, df$servicer_name != "")
nrow(df_snNoEmpty)
## [1] 292574
```

***
  
  
### Fill missing data entries
  
  
#### Null value entries
  
The `fillna` operation allows us to replace null entries with some specified value. In order to replace null entries in every numerical and integer column in `df` with a value, we simply evaluate the expression `fillna(df, <value>)`. We replace every null entry in `df` with the value 12345 below:


```r
str(df)
## 'SparkDataFrame': 14 variables:
##  $ loan_id      : num 404371459720 404371459720 404371459720 404371459720 404371459720 404371459720
##  $ period       : chr "09/01/2005" "10/01/2005" "11/01/2005" "12/01/2005" "01/01/2006" "02/01/2006"
##  $ servicer_name: chr "" "" "" "" "" ""
##  $ new_int_rt   : num 7.75 7.75 7.75 7.75 7.75 7.75
##  $ act_endg_upb : num 79331.2 79039.52 79358.51 79358.51 78365.73 78365.73
##  $ loan_age     : int 67 68 69 70 71 72
##  $ mths_remng   : int 293 292 291 290 289 288
##  $ aj_mths_remng: int 286 283 287 287 277 277
##  $ dt_matr      : chr "02/2030" "02/2030" "02/2030" "02/2030" "02/2030" "02/2030"
##  $ cd_msa       : int 0 0 0 0 0 0
##  $ delq_sts     : chr "5" "3" "8" "9" "0" "1"
##  $ flag_mod     : chr "N" "N" "N" "N" "N" "N"
##  $ cd_zero_bal  : int NA NA NA NA NA NA
##  $ dt_zero_bal  : chr "" "" "" "" "" ""

df_ <- fillna(df, value = 12345)
str(df_)
## 'SparkDataFrame': 14 variables:
##  $ loan_id      : num 404371459720 404371459720 404371459720 404371459720 404371459720 404371459720
##  $ period       : chr "09/01/2005" "10/01/2005" "11/01/2005" "12/01/2005" "01/01/2006" "02/01/2006"
##  $ servicer_name: chr "" "" "" "" "" ""
##  $ new_int_rt   : num 7.75 7.75 7.75 7.75 7.75 7.75
##  $ act_endg_upb : num 79331.2 79039.52 79358.51 79358.51 78365.73 78365.73
##  $ loan_age     : int 67 68 69 70 71 72
##  $ mths_remng   : int 293 292 291 290 289 288
##  $ aj_mths_remng: int 286 283 287 287 277 277
##  $ dt_matr      : chr "02/2030" "02/2030" "02/2030" "02/2030" "02/2030" "02/2030"
##  $ cd_msa       : int 0 0 0 0 0 0
##  $ delq_sts     : chr "5" "3" "8" "9" "0" "1"
##  $ flag_mod     : chr "N" "N" "N" "N" "N" "N"
##  $ cd_zero_bal  : int 12345 12345 12345 12345 12345 12345
##  $ dt_zero_bal  : chr "" "" "" "" "" ""
rm(df_)
```

If we want to replace null values within a list of DF columns, we can specify a column list just as we did in `dropna`. Here, we replace the null values in only `"act_endg_upb"` with 12345:
  

```r
str(df)
## 'SparkDataFrame': 14 variables:
##  $ loan_id      : num 404371459720 404371459720 404371459720 404371459720 404371459720 404371459720
##  $ period       : chr "09/01/2005" "10/01/2005" "11/01/2005" "12/01/2005" "01/01/2006" "02/01/2006"
##  $ servicer_name: chr "" "" "" "" "" ""
##  $ new_int_rt   : num 7.75 7.75 7.75 7.75 7.75 7.75
##  $ act_endg_upb : num 79331.2 79039.52 79358.51 79358.51 78365.73 78365.73
##  $ loan_age     : int 67 68 69 70 71 72
##  $ mths_remng   : int 293 292 291 290 289 288
##  $ aj_mths_remng: int 286 283 287 287 277 277
##  $ dt_matr      : chr "02/2030" "02/2030" "02/2030" "02/2030" "02/2030" "02/2030"
##  $ cd_msa       : int 0 0 0 0 0 0
##  $ delq_sts     : chr "5" "3" "8" "9" "0" "1"
##  $ flag_mod     : chr "N" "N" "N" "N" "N" "N"
##  $ cd_zero_bal  : int NA NA NA NA NA NA
##  $ dt_zero_bal  : chr "" "" "" "" "" ""

df_ <- fillna(df, list("act_endg_upb" = 12345))
str(df_)
## 'SparkDataFrame': 14 variables:
##  $ loan_id      : num 404371459720 404371459720 404371459720 404371459720 404371459720 404371459720
##  $ period       : chr "09/01/2005" "10/01/2005" "11/01/2005" "12/01/2005" "01/01/2006" "02/01/2006"
##  $ servicer_name: chr "" "" "" "" "" ""
##  $ new_int_rt   : num 7.75 7.75 7.75 7.75 7.75 7.75
##  $ act_endg_upb : num 79331.2 79039.52 79358.51 79358.51 78365.73 78365.73
##  $ loan_age     : int 67 68 69 70 71 72
##  $ mths_remng   : int 293 292 291 290 289 288
##  $ aj_mths_remng: int 286 283 287 287 277 277
##  $ dt_matr      : chr "02/2030" "02/2030" "02/2030" "02/2030" "02/2030" "02/2030"
##  $ cd_msa       : int 0 0 0 0 0 0
##  $ delq_sts     : chr "5" "3" "8" "9" "0" "1"
##  $ flag_mod     : chr "N" "N" "N" "N" "N" "N"
##  $ cd_zero_bal  : int NA NA NA NA NA NA
##  $ dt_zero_bal  : chr "" "" "" "" "" ""
rm(df_)
```


#### Empty string entries

Finally, we can replace the empty entries in string dtype columns with the `ifelse` operation, which follows the syntax `ifelse(<test>, <if true>, <if false>)`. Here, we replace the empty entries in `"servicer_name"` with the string `"Unknown"`:
  

```r
str(df)
## 'SparkDataFrame': 14 variables:
##  $ loan_id      : num 404371459720 404371459720 404371459720 404371459720 404371459720 404371459720
##  $ period       : chr "09/01/2005" "10/01/2005" "11/01/2005" "12/01/2005" "01/01/2006" "02/01/2006"
##  $ servicer_name: chr "" "" "" "" "" ""
##  $ new_int_rt   : num 7.75 7.75 7.75 7.75 7.75 7.75
##  $ act_endg_upb : num 79331.2 79039.52 79358.51 79358.51 78365.73 78365.73
##  $ loan_age     : int 67 68 69 70 71 72
##  $ mths_remng   : int 293 292 291 290 289 288
##  $ aj_mths_remng: int 286 283 287 287 277 277
##  $ dt_matr      : chr "02/2030" "02/2030" "02/2030" "02/2030" "02/2030" "02/2030"
##  $ cd_msa       : int 0 0 0 0 0 0
##  $ delq_sts     : chr "5" "3" "8" "9" "0" "1"
##  $ flag_mod     : chr "N" "N" "N" "N" "N" "N"
##  $ cd_zero_bal  : int NA NA NA NA NA NA
##  $ dt_zero_bal  : chr "" "" "" "" "" ""
df$servicer_name <- ifelse(df$servicer_name == "", "Unknown", df$servicer_name)
str(df)
## 'SparkDataFrame': 14 variables:
##  $ loan_id      : num 404371459720 404371459720 404371459720 404371459720 404371459720 404371459720
##  $ period       : chr "09/01/2005" "10/01/2005" "11/01/2005" "12/01/2005" "01/01/2006" "02/01/2006"
##  $ servicer_name: chr "Unknown" "Unknown" "Unknown" "Unknown" "Unknown" "Unknown"
##  $ new_int_rt   : num 7.75 7.75 7.75 7.75 7.75 7.75
##  $ act_endg_upb : num 79331.2 79039.52 79358.51 79358.51 78365.73 78365.73
##  $ loan_age     : int 67 68 69 70 71 72
##  $ mths_remng   : int 293 292 291 290 289 288
##  $ aj_mths_remng: int 286 283 287 287 277 277
##  $ dt_matr      : chr "02/2030" "02/2030" "02/2030" "02/2030" "02/2030" "02/2030"
##  $ cd_msa       : int 0 0 0 0 0 0
##  $ delq_sts     : chr "5" "3" "8" "9" "0" "1"
##  $ flag_mod     : chr "N" "N" "N" "N" "N" "N"
##  $ cd_zero_bal  : int NA NA NA NA NA NA
##  $ dt_zero_bal  : chr "" "" "" "" "" ""
```


__End of tutorial__ - Next up is [Computing Summary Statistics with SparkR](https://github.com/UrbanInstitute/sparkr-tutorials/blob/master/summary-statistics.md)

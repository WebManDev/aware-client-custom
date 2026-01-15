package com.aware;
import com.aware.utils.Aware_Sensor;
import java.util.ArrayList;
import android.content.ContentValues;
import java.util.List;

public class TimeLatency extends Aware_Sensor {
 // Tracks beginning and end time of a question
     private List<ContentValues> data_values = new ArrayList<ContentValues>();
    public ContentValues startTime(int questionId) {
        long beginningTime=System.currentTimeMillis();
        ContentValues dataForStartingTime = new ContentValues();

        dataForStartingTime.put("question_id", questionId);
        dataForStartingTime.put("start_time", beginningTime);
        dataForStartingTime.put("starting_timestamp", beginningTime);
        data_values.add(dataForStartingTime);
        return dataForStartingTime;
    }
    private ContentValues searchingQuestion(int questionId) {
       for (int a = 0; a < data_values.size(); a= a+1) {
            ContentValues data = data_values.get(a);
           if (data.getAsInteger("question_id") == questionId) {
               return data;
           }
       }
       return null;
   }

    public ContentValues questionAnswered(int questionId) {
        long timeCompleted=System.currentTimeMillis();
        
        ContentValues dataForCompletedTime = searchingQuestion(questionId);
        if (dataForCompletedTime == null) {
            return null; // Question not found
        }
        long beginningTime = dataForCompletedTime.getAsLong("start_time");
        long timeTaken = timeCompleted - beginningTime;

        dataForCompletedTime.put("end_time", timeCompleted);
        dataForCompletedTime.put("ending_timestamp", timeCompleted);
        dataForCompletedTime.put("time_taken",timeTaken);
        return dataForCompletedTime;
       // function code
    }


   }

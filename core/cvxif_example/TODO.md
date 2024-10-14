# TODO

[DOCUMENTACION OFICIAL](https://docs.openhwgroup.org/projects/cva6-user-manual/01_cva6_user/CVX_Interface_Coprocessor.html)

### Consideraciones

Como hago para conectar los registros del procesador con los de la unidad
vectorial?  
Como consigo hacer lecturas y escrituras en memoria?  
Como consigo hacer lecturas y escrituras con stride y/o indices?  
Donde se activa el parametro `CVA6ConfigCvxifEn` mencionado en la documentacion?

### Cosas que el coprocesador tiene que hacer respecto al procesador

##### Instrucciones Ilegales

The CVA6 decoder module detects illegal instructions for the CVA6,
prepares exception field with relevant information (exception code
“ILLEGAL INSTRUCTION”, instruction value).

The exception valid flag is raised in CVA6 decoder when CV-X-IF is disabled.
Otherwise it is not raised at this stage because the decision belongs to the
coprocessor after the offload process.

### Interafaces

* Issue (Request - Response)
* Commit 
* Result (Request - Response)
